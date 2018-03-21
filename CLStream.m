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

/* This is way up here so I can get the special functions that open
   files in RAM and the special function to return the current
   directory */
#define _GNU_SOURCE
#include <stdio.h>
#include <unistd.h>

#import "CLStream.h"
#import "CLFileStream.h"
#import "CLMemoryStream.h"
#import "CLPipeStream.h"
#import "CLString.h"
#import "CLData.h"
#import "CLArray.h"
#import "CLElement.h"
#import "CLManager.h"
#import "CLCharacterSet.h"
#import "CLMutableData.h"
#import "CLEditingContext.h"
#import "CLStringFunctions.h"
#import "CLStackString.h"
#import "CLClassConstants.h"

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
#include <math.h>
#include <string.h>
#include <endian.h>

#ifndef le32toh
#include <byteswap.h>
#if __BYTE_ORDER == __LITTLE_ENDIAN
#define le32toh(x) (x)
#define le64toh(x) (x)
#define htole32(x) (x)
#else
#define le32toh(x) __bswap_32 (x)
#define le64toh(x) __bswap_64 (x)
#define htole32(x) __bswap_32 (x)
#endif
#endif /* le32toh */

#define BUFSIZE		256
#define FILE_DIR	@"filedb"
#define FILE_SEQ	@"sequence"
#define IMAGE_DIR	@"imagedb"
#define IMAGE_SEQ	@"sequence"

#define FILE_CMD	"/usr/local/bin/file"
#define ALTFILE_CMD	"/usr/bin/file"
#define MIME_TYPES	@"/etc/mime.types"

static CLString *CLFileDirectory = nil;

@implementation CLStream

+(CLString *) mimeTypeForFile:(CLString *) aPath
{
  const char *cmd = FILE_CMD;
  FILE *file;
  CLString *aString, *mimeType = nil;
  CLRange aRange;
  CLCharacterSet *ws = [CLCharacterSet whitespaceAndNewlineCharacterSet];


  if (access(cmd, X_OK))
    cmd = ALTFILE_CMD;

  aString = [CLString stringWithFormat:@"%s --mime-type %@", cmd, aPath];
  if ((file = popen([aString UTF8String], "r"))) {
    while ((aString = CLGets(file, CLUTF8StringEncoding)))
      if (!mimeType)
	mimeType = aString;
    pclose(file);

    aRange = [mimeType rangeOfString:@":"];
    mimeType = [[mimeType substringFromIndex:CLMaxRange(aRange)]
		     stringByTrimmingCharactersInSet:ws];
  }

  return mimeType;
}

-(void) dealloc
{
  if (streamObjects)
    CLHashTableFree(streamObjects);
  [super dealloc];
  return;
}

@end

@implementation CLStream (CLStreamObjects)

-(BOOL) readCharacter:(unichar *) c usingEncoding:(CLStringEncoding) enc
{
  CLMutableData *mData;
  CLString *aString;
  BOOL success = NO;
  int byte;

  
  mData = [[CLMutableData alloc] init];
  
  for (;;) {
    byte = [self readByte];
    if (byte == CLEOF)
      break;

    [mData appendByte:byte];    
    aString = [CLString stringWithData:mData encoding:enc];

    /* Don't process partial multi-byte characters */
    if ([aString length]) {
      *c = [aString characterAtIndex:0];
      success = YES;
      break;
    }
  }

  [mData release];
  return success;
}

-(CLData *) readDataOfLength:(int) len
{
  void *buf;
  int rlen;


  buf = malloc(len);
  rlen = [self read:buf length:len];
  if (rlen && rlen != CLEOF)
    return [CLData dataWithBytesNoCopy:buf length:rlen];

  free(buf);
  return nil;
}
 
-(void) writeData:(CLData *) aData
{
  [self write:[aData bytes] length:[aData length]];
  return;
}

-(CLString *) readStringUsingEncoding:(CLStringEncoding) enc
{
  CLMutableData *mData;
  CLString *aString = nil;
  int byte;
  char *buf;
  unsigned int buflen, pos;


  if (enc == CLUTF8StringEncoding || enc == CLASCIIStringEncoding) {
    buf = malloc(buflen = 256);
    pos = 0;
    for (;;) {
      byte = [self readByte];
      if (byte == CLEOF)
	break;
      if (pos == buflen)
	buf = realloc(buf, buflen *= 2);
      buf[pos++] = byte;
      if (byte == '\n')
	break;
    }

    if (pos)
      aString = [[CLString alloc] initWithBytesNoCopy:buf length:pos encoding:enc];
    else
      free(buf);
  }
  else {
    mData = [[CLMutableData alloc] init];
    do {
      byte = [self readByte];
      if (byte == CLEOF)
	break;
      [aString release];
      [mData appendByte:byte];
      aString = [[CLString alloc] initWithData:mData encoding:enc];
    } while (![aString length] || [aString characterAtIndex:[aString length] - 1] != '\n');

    [mData release];
  }
  
  return [aString autorelease];
}

-(void) writeString:(CLString *) aString usingEncoding:(CLStringEncoding) enc
{
  char *buf;
  CLUInteger blen;
  unistr *ustr;


  if (![aString length])
    return;
  
  CLCheckStringClass(aString);
  ustr = (unistr *) aString;
  CLStringConvertEncoding((char *) ustr->str, ustr->len * sizeof(unichar),
			  CLUnicodeStringEncoding,
			  &buf, &blen, enc, NO);
  [self write:buf length:blen];
  free(buf);
  return;
}

-(void) writeFormat:(CLString *) aFormat usingEncoding:(CLStringEncoding) enc, ...
{
  va_list ap;


  va_start(ap, enc);
  [self writeFormat:aFormat usingEncoding:enc arguments:ap];
  va_end(ap);
  return;
}

-(void) writeFormat:(CLString *) format usingEncoding:(CLStringEncoding) enc
	  arguments:(va_list) argList
{
  char *str;
  char *buf;
  CLUInteger blen;


  vasprintf(&str, [format UTF8String], argList);
  if (enc != CLUTF8StringEncoding)
    CLStringConvertEncoding(str, strlen(str), CLUTF8StringEncoding,
			    &buf, &blen, enc, NO);
  else {
    buf = str;
    blen = strlen(str);
  }

  [self write:buf length:blen];

  if (buf != str)
    free(buf);
  free(str);
  
  return;
}

@end

@implementation CLStream (CLStreamOpening)

+(CLStream *) openFileAtPath:(CLString *) aPath mode:(int) mode
{
  return [CLFileStream openFileAtPath:aPath mode:mode];
}

+(CLStream *) openTemporaryFile:(CLString *) template
{
  int fd;
  struct passwd *pw;
  const char *p;
  CLFileStream *oFile = nil;
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

  if (fd >= 0)
    oFile = [CLFileStream streamWithDescriptor:fd mode:CLReadWrite
					atPath:[CLString stringWithUTF8String:tbuf]
				     processID:0];
  
  if (tbuf)
    free(tbuf);

  return oFile;
}

+(CLStream *) openWithMemory:(void *) buf length:(int) len mode:(int) mode;
{
  return [CLMemoryStream openWithMemory:buf length:len mode:mode];
}

+(CLStream *) openWithData:(CLData *) aData mode:(int) mode
{
  return [CLMemoryStream openWithData:aData mode:mode];
}

+(CLStream *) openPipe:(CLString *) aCommand mode:(int) mode
{
  return [CLPipeStream streamWithCommand:aCommand mode:mode];
}

+(CLStream *) openPty:(CLString *) aCommand termios:(struct termios *) termp
	   windowSize:(struct winsize *) winp
{
  pid_t pid;
  char pty[MAXPATHLEN+1];
  int master;
  CLFileStream *oFile = nil;


  pid = forkpty(&master, pty, termp, winp);
  if (pid > 0) {
    oFile = [[CLFileStream alloc] initWithDescriptor:master
						path:[CLString stringWithUTF8String:pty]
					   processID:pid];
  }
  else if (pid == 0) { /* child */
    dup2(master, 0);
    dup2(master, 1);
    dup2(master, 2);
    close(master);
    
    execl("/bin/sh", "/bin/sh", "-c", [aCommand UTF8String], NULL);
  }

  return [oFile autorelease];
}

+(CLStream *) openDescriptor:(int) fd mode:(int) mode
{
  return [CLFileStream streamWithDescriptor:fd mode:mode atPath:nil processID:0];
}

+(CLStream *) openMemoryForWriting
{
  return [CLMemoryStream openWithMemory:NULL length:0 mode:CLReadWrite];
}

@end

@implementation CLStream (CLStreamArchiving)

/* Most of this archiving stuff is used for writing URLs. Want it to
   be as compact as possible. Head has variable length. Its end is
   marked by the first occurrence of a 0. Count the number of ones in
   head. The total number of bytes will be 2 ^ count.

   Should probably do something with negative numbers so they can be
   more compact. Maybe use the absolute value to determine size then
   convert back to twos complement before writing.

   
*/

-(int64_t) readInteger
{
  uint64_t val;
  int byte, i;


  val = i = 0;
  do {
    byte = [self readByte];
    if (byte == CLEOF)
      [self error:@"EOF before finished reading integer"];
    val |= ((uint64_t) (byte & 0x7f)) << 7 * i;
    i++;
  } while (byte & 0x80);

  return val;
}

-(void) writeInteger:(int64_t) aValue
{
  uint64_t val;
  int num;
  

  /* FIXME - do something better about negative values */

  val = aValue;
  val >>= 7;
  for (num = 1; val; num++, val >>= 7)
    ;

  for (val = aValue; num; num--, val >>= 7)
    [self writeByte:(num > 1 ? 0x80 : 0x00) | (val & 0x7f)];
  return;
}

-(void) readType:(CLString *) type data:(void *) data
{
  int32_t iVal;
  int64_t lVal;
  double dVal;
  unistr *ustr;


  ustr = CLStringToUnistr(type);
  switch (*ustr->str) {
  case _C_ID:
    /* FIXME - if this object is already unarchived, don't create a duplicate */
    {
      id anObject = nil;
      char *className;
      int len;
      size_t objHash;


      [self readType:@"i" data:&len];
      if (len) {
	className = calloc(1, len + 1);
	[self read:className length:len];
	objHash = [self readInteger];

	if (!streamObjects)
	  streamObjects = CLHashTableAlloc(100);
	if (!(anObject = CLHashTableDataForIdenticalKey(streamObjects,
							(id) objHash, objHash))) {
	  anObject = [objc_lookUpClass(className) alloc];
	  if ([anObject respondsTo:@selector(read:)])
	    anObject = [anObject read:self];
	  free(className);
	  CLHashTableSetData(streamObjects, anObject, (id) objHash, objHash);
	}
	else
	  [anObject retain];
      }

      *(id *) data = anObject;
    }
    break;

  case _C_CHR:
  case _C_UCHR:
  case _C_SHT:
  case _C_USHT:
  case _C_INT:
  case _C_UINT:
  case _C_LNG:
  case _C_ULNG:
  case _C_LNG_LNG:
  case _C_ULNG_LNG:
    lVal = [self readInteger];
    if (*ustr->str == _C_CHR || *ustr->str == _C_UCHR)
      *(int *) data = lVal;
    else if (*ustr->str == _C_SHT || *ustr->str == _C_USHT)
      *(short *) data = lVal;
    else if (*ustr->str == _C_INT || *ustr->str == _C_UINT)
      *(int *) data = lVal;
    else if (*ustr->str == _C_LNG || *ustr->str == _C_ULNG)
      *(long *) data = lVal;
    else if (*ustr->str == _C_LNG_LNG || *ustr->str == _C_ULNG_LNG)
      *(long long *) data = lVal;
    break;

  case _C_FLT:
    [self read:&iVal length:sizeof(iVal)];
    iVal = le32toh(iVal);
    dVal = INT32_MAX / iVal;
    [self read:&iVal length:sizeof(iVal)];
    iVal = le32toh(iVal);
    *(float *) data = ldexp(dVal, iVal);
    break;

  case _C_DBL:
    [self read:&lVal length:sizeof(lVal)];
    lVal = le64toh(lVal);
    dVal = INT64_MAX / lVal;
    [self read:&iVal length:sizeof(iVal)];
    iVal = le32toh(iVal);
    *(double *) data = ldexp(dVal, iVal);
    break;

  case _C_CHARPTR:
    {
      char *str = NULL;
      int len;


      [self readType:@"i" data:&len];
      if (len > -1) {
	str = calloc(1, len + 1);
	if (len)
	  [self read:str length:len];
      }
      *(char **) data = str;
    }
    break;

  case _C_SEL:
    {
      char *str = NULL;
      int len;


      [self readType:@"i" data:&len];
      if (len > -1) {
	str = calloc(1, len + 1);
	if (len)
	  [self read:str length:len];
      }
      *(SEL *) data = sel_getUid(str);
    }
    break;

  default:
    [self error:@"Unknown type %c", *ustr->str];
    break;
  }

  return;
}

-(void) writeType:(CLString *) type data:(void *) data
{
  int exp;
  int32_t iVal;
  int64_t lVal;
  unistr *ustr;


  ustr = CLStringToUnistr(type);
  
  switch (*ustr->str) {
  case _C_ID:
    /* FIXME - don't write the same object to the stream multiple times */
    {
      id anObject = *(id *) data;
      const char *className;
      int len = 0;


      if (anObject) {
	className = [[anObject className] UTF8String];
	len = strlen(className);
      }
      [self writeType:@"i" data:&len];
      if (len) {
	[self write:className length:len];
	[self writeInteger:(size_t) anObject];
	if (!streamObjects)
	  streamObjects = CLHashTableAlloc(100);
	if ([anObject respondsTo:@selector(write:)] &&
	    !CLHashTableDataForIdenticalKey(streamObjects, anObject, (size_t) anObject)) {
	  [anObject write:self];
	  CLHashTableSetData(streamObjects, anObject, anObject, (size_t) anObject);
	}
      }
    }
    break;

  case _C_CHR:
  case _C_UCHR:
  case _C_SHT:
  case _C_USHT:
  case _C_INT:
  case _C_UINT:
  case _C_LNG:
  case _C_ULNG:
  case _C_LNG_LNG:
  case _C_ULNG_LNG:
    if (*ustr->str == _C_CHR || *ustr->str == _C_UCHR)
      lVal = *(int *) data;
    else if (*ustr->str == _C_SHT || *ustr->str == _C_USHT)
      lVal = *(short *) data;
    else if (*ustr->str == _C_INT || *ustr->str == _C_UINT)
      lVal = *(int *) data;
    else if (*ustr->str == _C_LNG || *ustr->str == _C_ULNG)
      lVal = *(long *) data;
    else if (*ustr->str == _C_LNG_LNG || *ustr->str == _C_ULNG_LNG)
      lVal = *(long long *) data;
    [self writeInteger:lVal];
    break;

  case _C_FLT:
    iVal = INT32_MAX * frexp(*(float *) data, &exp);
    iVal = htole32(iVal);
    [self write:&iVal length:sizeof(iVal)];
    iVal = htole32(exp);
    [self write:&iVal length:sizeof(iVal)];
    break;

  case _C_DBL:
    lVal = INT64_MAX * frexp(*(float *) data, &exp);
    lVal = htole32(lVal);
    [self write:&lVal length:sizeof(lVal)];
    iVal = htole32(exp);
    [self write:&iVal length:sizeof(iVal)];
    break;

  case _C_CHARPTR:
    {
      const char *str = *(char **) data;
      int len = 0;


      /* FIXME - find a better way to write out NULL pointers or maybe
	 disallow them entirely? */
      if (!str)
	len = -1;
      else
	len = strlen(str);
      [self writeType:@"i" data:&len];
      if (len > 0)
	[self write:str length:len];
    }
    break;

  case _C_SEL:
    {
      const char *str = sel_getName(*(SEL *) data);
      int len = 0;


      len = strlen(str);
      [self writeType:@"i" data:&len];
      [self write:str length:len];
    }
    break;
    
  default:
    [self error:@"Unknown type %c", *ustr->str];
    break;
  }

  return;
}

-(void) readTypes:(CLString *) type, ...
{
  va_list args;
  unistr tstr;
  const char *c;


  va_start(args, type);

  tstr = CLNewStackString(1);
  tstr.len = 1;
  for (c = [type UTF8String]; *c; c = objc_skip_typespec(c)) {
    tstr.str[0] = *c;
    [self readType:(CLString *) &tstr data:va_arg(args, void *)];
  }
  va_end(args);
  
  return;
}

-(void) writeTypes:(CLString *) type, ...
{
  va_list args;
  unistr tstr;
  const char *c;


  va_start(args, type);

  tstr = CLNewStackString(1);
  tstr.len = 1;
  for (c = [type UTF8String]; *c; c = objc_skip_typespec(c)) {
    tstr.str[0] = *c;
    [self writeType:(CLString *) &tstr data:va_arg(args, void *)];
  }
  va_end(args);
  
  return;
}

@end

/* I/O as functions */

void CLPrintf(CLStream *stream, CLString *format, ...)
{
  va_list ap;


  va_start(ap, format);
  [stream writeFormat:format usingEncoding:CLUTF8StringEncoding arguments:ap];
  va_end(ap);
  return;
}

/* Legacy I/O */
CLString *CLGets(FILE *file, CLStringEncoding enc)
{
  char *buf;
  size_t buflen = 0;
  char *err;
  int pos;
  CLString *aString;
#if DEBUG_LEAK
  id self = nil;
#endif


  buf = malloc(buflen = 256);
  pos = 0;
  while ((err = fgets(buf + pos, buflen - pos, file))) {
    pos = strlen(buf);
    if (buf[pos-1] == '\n')
      break;
    if (buflen - pos < 2)
      buf = realloc(buf, buflen *= 2);
  }

  if (pos || err)  {
    aString = [CLString stringWithBytes:buf length:pos encoding:enc];
    free(buf);
  }
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
#if DEBUG_LEAK
  id self = nil;
#endif


  buf = malloc(buflen = 256);
  pos = 0;
  while ((len = read(fd, buf + pos, 1)) > 0) {
    pos++;
    if (buf[pos-1] == '\n')
      break;
    if (buflen - pos < 2)
      buf = realloc(buf, buflen *= 2);
  }

  if (len > 0) {
    aString = [CLString stringWithBytes:buf length:pos encoding:enc];
    free(buf);
  }
  else
    aString = nil;
  return aString;
}

void CLFindFileDirectory()
{
#if DEBUG_RETAIN
    id self = nil;
#endif
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

void CLCreateWorldWritableDirectory(CLString *aPath)
{
  struct stat st;
  

  mkdir([aPath UTF8String], 0777);
  stat([aPath UTF8String], &st);
  st.st_mode |= 0777;
  chmod([aPath UTF8String], st.st_mode);
  return;
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
  CLCreateWorldWritableDirectory(aPath);
  aPath = [aPath stringByAppendingPathComponent:
		     [CLString stringWithFormat:@"%i", (seq / 10) % 10]];
  CLCreateWorldWritableDirectory(aPath);
  aPath = [aPath stringByAppendingPathComponent:[CLString stringWithFormat:@"%i", seq]];
  if ((file = fopen([aPath UTF8String], "w"))) {
    if ([aData length])
      fwrite([aData bytes], 1, [aData length], file);
    fclose(file);

    if (!extension) {
      mimeType = [CLStream mimeTypeForFile:aPath];
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

int CLNextFileSequence()
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
  CLCreateWorldWritableDirectory(aPath);
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

  return seq;
}

int CLStoreFile(CLData *aData, CLString *extension, CLString *extensionHint)
{
  int seq;


  seq = CLNextFileSequence();
  if (!CLStoreFileAsID(aData, extension, extensionHint, seq))
    seq = 0;
  
  return seq;
}


void CLWriteHTMLObject(CLStream *stream, id anObject)
{
  int i, j;

  
  if ([anObject isKindOfClass:CLArrayClass]) {
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
#if DEBUG_RETAIN
  id self = nil;
#endif

  
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

    {
      unistr evil;
      CLMutableStackString *evilStack;
      CLUInteger max;


      aString2 = nil;
      for (i = max = 0, j = [extensions count]; i < j; i++)
	if ([[extensions objectAtIndex:i] length] > max)
	  max = [[extensions objectAtIndex:i] length];
      
      evil = CLCopyStackString(aString, max + 1);
      evilStack = (CLMutableStackString *) &evil;
      for (i = 0, j = [extensions count]; i < j; i++) {
	[evilStack setString:aString];
	[evilStack appendPathExtension:[extensions objectAtIndex:i]];
	if (!access([evilStack UTF8String], R_OK)) {
	  aString2 = [evilStack copy];
	  break;
	}
      }
    }
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
      unistr evil;
      CLMutableStackString *evilStack;


      evil = CLNewStackString([CLAppPath length] + [aFilename length] + 1);
      evilStack = (CLMutableStackString *) &evil;
      [evilStack setString:CLAppPath];
      [evilStack appendPathComponent:aFilename];
      if (!(aString = CLTryExtensions(evilStack, extensions)))
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
