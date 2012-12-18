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

/* This is way up here so I can get the special functions that open
   files in RAM and the special function to return the current
   directory */
#define _GNU_SOURCE
#include <stdio.h>
#include <unistd.h>

#import "CLStream.h"
#import "CLString.h"
#import "CLOpenFile.h"
#import "CLData.h"
#import "CLArray.h"
#import "CLElement.h"
#import "CLManager.h"
#import "CLCharacterSet.h"
#import "CLMutableData.h"
#import "CLGenericRecord.h"
#import <objc/objc-api.h>
#import <objc/encoding.h>

#include <stdlib.h>
#include <stdarg.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <pwd.h>
#include <fcntl.h>
#include <sys/file.h>
#include <dirent.h>
#include <sys/param.h>
#include <zlib.h>

#define FILE_DIR	@"filedb"
#define FILE_SEQ	@"sequence"
#define IMAGE_DIR	@"imagedb"
#define IMAGE_SEQ	@"sequence"

#define FILE_CMD	@"/usr/local/bin/file"
#define MIME_TYPES	@"/etc/mime.types"

static CLString *CLFileDirectory = nil;

extern int objc_write_string(struct objc_typed_stream *stream,
			     const unsigned char *string,
			     unsigned int nbytes);

/* Having to add a lot of complexity to this because of using a shared
   server and the idiots filled /tmp on me */

#define TEMPLATE	"clstream.XXXXXX"

CLOpenFile *CLTemporaryFile(CLString *template)
{
  int fd;
  struct passwd *pw;
  const char *p;
  FILE *file;
  CLOpenFile *oFile = nil;
  char *tbuf;


  p = [[CLString stringWithFormat:@"/tmp/%@", template] UTF8String];
  tbuf = strdup(p);
  fd = mkstemp(tbuf);

  if (fd < 0 && (p = getenv("TMPDIR"))) {
    free(tbuf);
    tbuf = strdup([[[CLString stringWithUTF8String:p]
		     stringByAppendingPathComponent:template] UTF8String]);
    fd = mkstemp(tbuf);
  }

  if (fd < 0) {
    CLString *aString;

    
    /* Try to make a temp file in our home */
    pw = getpwuid(getuid());
    aString = [[CLString stringWithUTF8String:pw->pw_dir]
		stringByAppendingPathComponent:@"tmp"];
    if (!mkdir([aString UTF8String], 0700))
      setenv("TMPDIR", [aString UTF8String], 1);
    free(tbuf);
    tbuf = strdup([[aString stringByAppendingPathComponent:template] UTF8String]);
    fd = mkstemp(tbuf);
  }

  if (fd >= 0) {
    file = fdopen(fd, "r+");
    oFile = [[CLOpenFile alloc] initWithFile:file path:[CLString stringWithUTF8String:tbuf]
				pid:0];
  }
  
  if (tbuf)
    free(tbuf);

  return [oFile autorelease];
}

CLStream *CLOpenMemory(const char *buf, int len, int mode)
{
  CLStream *stream = NULL;


  stream = calloc(1, sizeof(CLStream));
  
  switch (mode) {
  case CL_READONLY:
    stream->file = fmemopen((void *) buf, len, "r");
    break;
      
  case CL_WRITEONLY:
  case CL_READWRITE:
    stream->file = open_memstream(&stream->buf, &stream->len);
    break;
  }

  return stream;
}

void CLCloseMemory(CLStream *stream, int mode)
{
  fclose(stream->file);
  if (stream->buf)
    free(stream->buf);
  free(stream);
  return;
}

void CLGetMemoryBuffer(CLStream *stream, char **data, int *len, int *alloced)
{
  fflush(stream->file);
  *data = stream->buf;
  *len = stream->len;
  *alloced = stream->len;
  
  return;
}

CLData *CLGetData(CLStream *stream)
{
  fflush(stream->file);
  return [CLData dataWithBytes:stream->buf length:stream->len];
}

int CLGetc(CLStream *stream)
{
  return getc(stream->file);
}

void CLPutc(CLStream *stream, int c)
{
  putc(c, stream->file);
  return;
}

int CLRead(CLStream *stream, char *buf, int len)
{
  return fread(buf, 1, len, stream->file);
}

void CLWrite(CLStream *stream, const void *buf, int len)
{
  fwrite(buf, 1, len, stream->file);
  return;
}

void CLPrintf(CLStream *stream, CLString *format, ...)
{
  va_list ap;


  va_start(ap, format);
  vfprintf(stream->file, [format UTF8String], ap);
  va_end(ap);
  return;
}

id CLReadObject(CLTypedStream *stream)
{
  id anObject, newObject;


  objc_read_object(stream, &anObject);
  /* FIXME - this shouldn't be here. Yes it will leak because
     releasing things read in from the stream seems to cause
     problems. */
  if ([anObject isKindOfClass:[CLGenericRecord class]]) {
    newObject = [CLGenericRecord registerInstance:anObject];
    if (newObject && newObject != anObject)
      anObject = newObject;
  }
  
  return anObject;
}

CLTypedStream *CLOpenTypedStream(CLStream *stream, int mode)
{
  return objc_open_typed_stream(stream->file, mode);
}

int CLReadType(CLTypedStream *stream, const char *type, void *data)
{
  char *p;
  int len;
  id anObject, newObject;
  
  
  switch (*type) {
  case _C_CHARPTR:
    len = objc_read_type(stream, type, &p);
    if (!len) {
      *(char **)data = NULL;
      free(p);
    }
    else
      *(char **)data = p;
    return len;
    break;

  default:
    len = objc_read_type(stream, type, data);
    anObject = *(id *) data;
    if (*type == _C_ID && [anObject isKindOfClass:[CLGenericRecord class]]) {
      newObject = [CLGenericRecord registerInstance:anObject];
      if (newObject && newObject != anObject)
	anObject = newObject;
      *(id *) data = anObject;
    }
    return len;
  }

  return -1;
}
    
int CLWriteType(CLTypedStream *stream, const char *type, const void *data)
{
  const char *p;


  switch (*type) {
  case _C_CHARPTR:
    p = *(char **)data;
    if (!p)
      return objc_write_string(stream, (unsigned char *) "", 0);
    else
      return objc_write_string(stream, (unsigned char *) p, strlen(p));
    break;

  default:
    return objc_write_type(stream, type, data);
  }
  
  return -1;
}

int CLReadTypes(CLTypedStream *stream, const char *type, ...)
{
  const char *c;
  va_list args;


  va_start(args, type);

  for (c = type; *c; c = objc_skip_typespec(c))
    CLReadType(stream, c, va_arg(args, void *));
  va_end(args);
  
  return 0;
}
  
int CLWriteTypes(CLTypedStream *stream, const char *type, ...)
{
  const char *c;
  va_list args;


  va_start(args, type);

  for (c = type; *c; c = objc_skip_typespec(c))
    CLWriteType(stream, c, va_arg(args, void *));
  va_end(args);
  
  return 0;
}

long CLTell(CLStream *stream)
{
  return ftell(stream->file);
}

void CLSeek(CLStream *stream, long offset, int whence)
{
  fseek(stream->file, offset, whence);
  return;
}

CLString *CLGets(FILE *file, CLStringEncoding enc)
{
  char *buf;
  size_t buflen = 0;
  char *err;
  int pos;
  CLString *aString;


  buf = malloc(buflen = 256);
  pos = 0;
  while ((err = fgets(buf + pos, buflen - pos, file))) {
    pos = strlen(buf);
    if (buf[pos-1] == '\n')
      break;
    if (buflen - pos < 2)
      buf = realloc(buf, buflen *= 2);
  }

  if (pos || err) 
    aString = [CLString stringWithBytesNoCopy:buf length:pos encoding:enc];
  else
    aString = nil;
  return aString;
}

CLString *CLGetsfd(int fd, CLStringEncoding enc)
{
  char *buf;
  size_t buflen = 0;
  int pos, len;
  CLString *aString;


  buf = malloc(buflen = 256);
  pos = 0;
  while ((len = read(fd, buf + pos, 1)) > 0) {
    pos++;
    if (buf[pos-1] == '\n')
      break;
    if (buflen - pos < 2)
      buf = realloc(buf, buflen *= 2);
  }

  if (len > 0)
    aString = [CLString stringWithBytesNoCopy:buf length:pos encoding:enc];
  else
    aString = nil;
  return aString;
}

void CLFindFileDirectory()
{
  if (!CLFileDirectory) {
    if ([CLDelegate respondsTo:@selector(delegateGetFileDirectory)])
      CLFileDirectory = [[CLDelegate delegateGetFileDirectory] copy];
    else
      CLFileDirectory = [[[CLString stringWithUTF8String:getenv("DOCUMENT_ROOT")]
			   stringByAppendingPathComponent:FILE_DIR] retain];
  }

  return;
}

CLString *CLPathForFileID(int file_id)
{
  CLString *aPath;
  DIR *dir;
  struct dirent *dp;
  int i;
  char buf[20];


  CLFindFileDirectory();
  
  aPath = [CLFileDirectory stringByAppendingPathComponent:
			       [CLString stringWithFormat:@"%i/%i",
					 file_id % 10, (file_id / 10) % 10]];
  sprintf(buf, "%i", file_id);

  if (!(dir = opendir([aPath UTF8String])))
    return nil;

  i = strlen(buf);
  for (dp = readdir(dir); dp; dp = readdir(dir))
    if (dp->d_name[0] != '.' &&
	(strlen(dp->d_name) == i || (strlen(dp->d_name) > i && dp->d_name[i] == '.')) &&
	!strncmp(buf, dp->d_name, i)) {
      aPath = [aPath stringByAppendingPathComponent:
		       [CLString stringWithUTF8String:dp->d_name]];
      break;
    }
  closedir(dir);
  if (!dp)
    aPath = nil;

  return aPath;
}

BOOL CLStoreFileAsID(CLData *aData, CLString *extension, CLString *extensionHint, int seq)
{
  CLString *aPath, *aString, *mimeType = nil;
  FILE *file;
  CLRange aRange;
  CLArray *anArray;
  CLCharacterSet *ws = [CLCharacterSet whitespaceAndNewlineCharacterSet];
  int i, j;

  
  CLFindFileDirectory();
  
  aPath = [CLFileDirectory stringByAppendingPathComponent:
			       [CLString stringWithFormat:@"%i", seq % 10]];
  mkdir([aPath UTF8String], 0755);
  aPath = [aPath stringByAppendingPathComponent:
		     [CLString stringWithFormat:@"%i", (seq / 10) % 10]];
  mkdir([aPath UTF8String], 0755);
  aPath = [aPath stringByAppendingPathComponent:[CLString stringWithFormat:@"%i", seq]];
  if ((file = fopen([aPath UTF8String], "w"))) {
    fwrite([aData bytes], 1, [aData length], file);
    fclose(file);

    if (!extension) {
      aString = [CLString stringWithFormat:@"%@ --mime-type %@", FILE_CMD, aPath];
      if ((file = popen([aString UTF8String], "r"))) {
	while ((aString = CLGets(file, CLUTF8StringEncoding)))
	  if (!mimeType)
	    mimeType = aString;
	pclose(file);

	aRange = [mimeType rangeOfString:@":"];
	mimeType = [[mimeType substringFromIndex:CLMaxRange(aRange)]
		     stringByTrimmingCharactersInSet:ws];
	if (mimeType && (file = fopen([MIME_TYPES UTF8String], "r"))) {
	  while ((aString = CLGets(file, CLUTF8StringEncoding))) {
	    aString = [aString stringByTrimmingCharactersInSet:ws];
	    if (![aString length] || [aString characterAtIndex:0] == '#')
	      continue;
	    aRange = [aString rangeOfCharacterFromSet:ws];
	    if (aRange.length &&
		[[aString substringToIndex:aRange.location] isEqualToString:mimeType]) {
	      anArray = [[[aString substringFromIndex:CLMaxRange(aRange)]
			   stringByTrimmingCharactersInSet:ws]
			  componentsSeparatedByString:@" "];

	      for (i = 0, j = [anArray count]; extensionHint && i < j; i++)
		if (![[anArray objectAtIndex:i] caseInsensitiveCompare:extensionHint]) {
		  extension = [anArray objectAtIndex:i];
		  break;
		}

	      if (!extension)
		extension = [anArray objectAtIndex:0];
	      break;
	    }
	  }
	  fclose(file);
	}
      }
    }

    if ([extension length]) {
      aString = [aPath stringByAppendingPathExtension:extension];
      link([aPath UTF8String], [aString UTF8String]);
      unlink([aPath UTF8String]);
    }
  }
  else
    seq = 0;

  return !!seq;
}

int CLStoreFile(CLData *aData, CLString *extension, CLString *extensionHint)
{
  int fd;
  FILE *file;
  int seq = 1, iseq = 0;
  CLString *aPath, *aString;
  const char *p;


  /* FIXME - chmod the new dirs to the same permissions as the
     parent. Fix owner too if possible */
  
  p = getenv("DOCUMENT_ROOT");
  aPath = [CLString stringWithFormat:@"%s/%@/%@", p, IMAGE_DIR, IMAGE_SEQ];
  if ((file = fopen([aPath UTF8String], "r"))) {
    if ((aString = CLGets(file, CLUTF8StringEncoding)))
      iseq = [aString intValue];
    fclose(file);
  }

  CLFindFileDirectory();
  
  aPath = CLFileDirectory;
  mkdir([aPath UTF8String], 0755);
  aPath = [aPath stringByAppendingPathComponent:FILE_SEQ];
  if ((fd = open([aPath UTF8String], O_RDWR | O_CREAT, 0644)) >= 0) {
    if (!flock(fd, LOCK_EX) && (file = fdopen(fd, "r+"))) {
      if ((aString = CLGets(file, CLUTF8StringEncoding)))
	seq = [aString intValue];
      if (!seq)
	seq = 1;
      if (iseq > seq)
	seq = iseq;
      rewind(file);
      fprintf(file, "%i\n", seq + 1);
      fclose(file);
    }
    else
      close(fd);
  }

  if (!CLStoreFileAsID(aData, extension, extensionHint, seq))
    seq = 0;
  
  return seq;
}


void CLWriteHTMLObject(CLStream *stream, id anObject)
{
  int i, j;

  
  if ([anObject isKindOfClass:[CLArray class]]) {
    for (i = 0, j = [anObject count]; i < j; i++)
      CLWriteHTMLObject(stream, [anObject objectAtIndex:i]);
  }
  else if ([anObject respondsTo:@selector(writeHTML:)])
    [anObject writeHTML:stream];
  else if (anObject)
    CLPrintf(stream, @"%@", [anObject description]);

  return;
}

static CLString *CLTryExtensions(CLString *aFilename, CLArray *extensions)
{
  CLString *aString, *aString2 = nil;
  int i, j;

  
  if (access([aFilename UTF8String], R_OK)) {
    aString = [aFilename pathExtension];
    if ([aString length]) {
      for (i = 0, j = [extensions count]; i < j; i++)
	if (![aString isEqualToString:[extensions objectAtIndex:i]])
	  break;
      if (i < j)
	aString = [aFilename stringByDeletingPathExtension];
      else
	aString = aFilename;
    }
    else
      aString = aFilename;
    
    for (i = 0, j = [extensions count]; i < j; i++) {
      aString2 = [aString stringByAppendingPathExtension:[extensions objectAtIndex:i]];
      if (!access([aString2 UTF8String], R_OK))
	break;
    }
    if (i == j)
      aString2 = nil;
    [aString2 retain];    
  }
  else
    aString2 = [aFilename copy];

  return [aString2 autorelease];
}

CLString *CLFullPathForFile(CLString *aFilename, CLArray *extensions,
			    CLArray *directories)
{
  CLString *aString = nil, *newFilename;
  int i, j;


  if (![aFilename isAbsolutePath]) {
    for (i = 0, j = [directories count]; i < j; i++) {
      newFilename = [[directories objectAtIndex:i] stringByAppendingPathComponent:aFilename];
      if (!(aString = CLTryExtensions(newFilename, extensions)) &&
	  ![newFilename isAbsolutePath]) {
	newFilename = [CLAppPath stringByAppendingPathComponent:newFilename];
	aString = CLTryExtensions(newFilename, extensions);
      }
      if (aString)
	break;
    }
  }

  if (!aString) {
    if (![aFilename isAbsolutePath]) {
      if (!(aString = CLTryExtensions([CLAppPath stringByAppendingPathComponent:aFilename],
				      extensions)))
	aString = CLTryExtensions(aFilename, extensions);
    }
    else
      aString = CLTryExtensions(aFilename, extensions);
  }

  if (aString && ![aString isAbsolutePath]) {
    char *buf;

  
    buf = get_current_dir_name();
    aString = [[CLString stringWithUTF8String:buf] stringByAppendingPathComponent:aString];
  }

  return aString;
}

CLOpenFile *CLPtyOpen(CLString *aCommand, struct termios *termp, struct winsize *winp)
{
  pid_t pid;
  char pty[MAXPATHLEN+1];
  int master;
  CLOpenFile *oFile = nil;
  FILE *file;


  pid = forkpty(&master, pty, termp, winp);
  if (pid > 0) {
    if ((file = fdopen(master, "r+")))
      oFile = [[CLOpenFile alloc] initWithFile:file path:[CLString stringWithUTF8String:pty]
				  pid:pid];
  }
  else if (pid == 0) /* child */
    execl("/bin/sh", "/bin/sh", "-c", [aCommand UTF8String], NULL);

  return [oFile autorelease];
}

CLOpenFile *CLPipeOpen(CLString *aCommand, CLString *type)
{
  pid_t pid;
  CLOpenFile *oFile = nil;
  FILE *file;
  int wp[2], rp[2];
  int tty;
  int fd, maxf;


  pipe(wp);
  pipe(rp);

  pid = fork();
  if (pid > 0) {
    close(wp[0]);
    close(rp[1]);
    if ([type characterAtIndex:0] == 'r') {
      close(wp[1]);
      file = fdopen(rp[0], "r");
    }
    else {
      close(rp[0]);
      file = fdopen(wp[1], "w");
    }
    oFile = [[CLOpenFile alloc] initWithFile:file path:nil pid:pid];
  }
  else if (pid == 0) { /* child */
    dup2(wp[0], 0);
    dup2(rp[1], 1);
    dup2(rp[1], 2);

    maxf = getdtablesize();
    for (fd = 3; fd < maxf; fd++)
      close(fd);

    if ((tty = open("/dev/tty", O_RDWR)) >= 0) {
      ioctl(tty, TIOCNOTTY, 0);
      close(tty);
    }
    
    execl("/bin/sh", "/bin/sh", "-c", [aCommand UTF8String], NULL);
  }

  return [oFile autorelease];
}

int CLDeflate(const void *data, int len, int level, CLData **aData)
{
  int ret, flush;
  unsigned have;
  z_stream strm;
  unsigned char out[16384];
  CLMutableData *mData;
  

  
  strm.zalloc = Z_NULL;
  strm.zfree = Z_NULL;
  strm.opaque = Z_NULL;
  if ((ret = deflateInit2(&strm, level, Z_DEFLATED, 15|16, 8, Z_DEFAULT_STRATEGY)))
    return ret;

  strm.avail_in = len;
  strm.next_in = (unsigned char *) data;

  mData = [CLMutableData data];

  do {
    flush = strm.avail_in ? Z_NO_FLUSH : Z_FINISH;
  
    strm.avail_out = sizeof(out);
    strm.next_out = out;
    if ((ret = deflate(&strm, flush)) != Z_OK && ret != Z_STREAM_END)
      break;

    have = sizeof(out) - strm.avail_out;
    [mData appendBytes:out length:have];
  } while (!ret);

  if (ret == Z_STREAM_END)
    ret = Z_OK;
  
  deflateEnd(&strm);

  *aData = mData;
  return ret;
}
