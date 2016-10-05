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

/* FIXME - Bleh - and now we are dependent on OpenSSL. Use a public
   domain implementation */
#include <openssl/md5.h>
#include <openssl/hmac.h>

#import "CLData.h"
#import "CLString.h"
#import "CLMutableData.h"
#import "CLStream.h"
#import "CLNumber.h"
#import "CLMutableArray.h"
#import "CLMutableDictionary.h"
#import "CLMutableString.h"

#include <stdlib.h>
#include <dirent.h>
#include <unistd.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <string.h>

#define BUFSIZE	256

/* FIXME - don't declare this both here and in CLString */
static char *base64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";

@implementation CLData

+(id) data
{
  return [[[self alloc] init] autorelease];
}

+(id) dataWithBytes:(const void *) bytes length:(CLUInteger) length
{
  return [[[self alloc] initWithBytes:bytes length:length] autorelease];
}

+(id) dataWithBytesNoCopy:(const void *) bytes length:(CLUInteger) length
{
  return [[[self alloc] initWithBytesNoCopy:bytes length:length] autorelease];
}

+(id) dataWithContentsOfFile:(CLString *) path
{
  return [[[self alloc] initWithContentsOfFile:path] autorelease];
}

-(id) init
{
  [super init];
  data = NULL;
  len = 0;
  return self;
}
  
-(id) initWithBytes:(const void *) bytes length:(CLUInteger) length
{
  [self init];
  if (!(data = malloc(length)))
    [self error:@"Unable to allocate memory"];
  memcpy(data, bytes, length);
  len = length;
  return self;
}

-(id) initWithBytesNoCopy:(void *) bytes length:(CLUInteger) length
{
  [self init];
  data = bytes;
  len = length;
  return self;
}

-(id) initWithContentsOfFile:(CLString *) path
{
  FILE *file;
  struct stat st;


  [self init];

  if (!stat([path UTF8String], &st) && (file = fopen([path UTF8String], "r"))) {
    if (!(data = malloc(len = st.st_size)))
      [self error:@"Unable to allocate memory"];
    fread(data, 1, len, file);
    fclose(file);
  }

  return self;
}

-(void) dealloc
{
  free(data);
  [super dealloc];
  return;
}

-(id) mutableCopy
{
  return [[CLMutableData alloc] initWithBytes:data length:len];
}

-(id) read:(CLStream *) stream
{
  [super read:stream];
  [stream readType:@"I" data:&len];
  if (!(data = malloc(len)))
    [self error:@"Unable to allocate memory"];
  [stream read:data length:len];
  return self;
}

-(void) write:(CLStream *) stream
{
  [super write:stream];
  [stream writeType:@"I" data:&len];
  [stream write:data length:len];
  return;
}

-(const void *) bytes
{
  return data;
}

-(CLUInteger) length
{
  return len;
}

-(CLString *) encodeBase64
{
  return [self encodeBase64WithCharacters:base64];
}

-(CLString *) encodeBase64WithCharacters:(const char *) baseChars
{
  int i, j;
  const unsigned char *p = (unsigned char *) data;
  char *q;
  char *r;
  CLString *aString;
  

  if (!(q = malloc(len*2+3))) /* It's gonna be less than or equal to that */
    [self error:@"Unable to allocate memory"];
  for (i = 0, r = q; i < len; i += 3) {
    switch (len - i) {
    case 1:
      j = p[i] << 16;
      *r++ = baseChars[(j >> 18) & 0x3f];
      *r++ = baseChars[(j >> 12) & 0x3f];
      *r++ = '=';
      *r++ = '=';
      break;

    case 2:
      j = p[i] << 16;
      j |= p[i+1] << 8;
      *r++ = baseChars[(j >> 18) & 0x3f];
      *r++ = baseChars[(j >> 12) & 0x3f];
      *r++ = baseChars[(j >> 6) & 0x3f];
      *r++ = '=';
      break;

    default:
      j = p[i] << 16;
      j |= p[i+1] << 8;
      j |= p[i+2] << 0;
      *r++ = baseChars[(j >> 18) & 0x3f];
      *r++ = baseChars[(j >> 12) & 0x3f];
      *r++ = baseChars[(j >> 6) & 0x3f];
      *r++ = baseChars[(j >> 0) & 0x3f];
      break;
    }
  }

  *r = 0;
  
  aString = [CLString stringWithUTF8String:q];
  free(q);
  return aString;
}

-(id) decodeBObject:(CLUInteger *) pos
{
  CLUInteger i = *pos, j;
  id anObject = nil;
  id aKey, aValue;
  long long ll;
  BOOL neg;

  
  switch (data[i]) {
  case 'i':
    i++;
    for (ll = 0, neg = NO; i < len && data[i] != 'e'; i++) {
      if (data[i] == '-')
	neg = YES;
      else {
	ll *= 10;
	ll += data[i] - '0';
      }
    }
    if (neg)
      ll *= -1;
    anObject = [CLNumber numberWithLongLong:ll];
    if (i < len)
      i++;
    break;

  case 'l':
    i++;
    anObject = [[[CLMutableArray alloc] init] autorelease];
    while (i < len && data[i] != 'e')
      [anObject addObject:[self decodeBObject:&i]];
    if (i < len)
      i++;
    break;

  case 'd':
    i++;
    anObject = [[[CLMutableDictionary alloc] init] autorelease];
    while (i < len && data[i] != 'e') {
      aKey = [self decodeBObject:&i];
      aValue = [self decodeBObject:&i];
      [anObject setObject:aValue forKey:aKey];
    }
    if (i < len)
      i++;
    break;

  case '0': case '1': case '2': case '3': case '4':
  case '5': case '6': case '7': case '8': case '9':
    for (ll = 0; i < len && data[i] != ':'; i++) {
      ll *= 10;
      ll += data[i] - '0';
    }
    if (i < len)
      i++;
    if (i + ll < len) {
      for (j = i; j < i+ll; j++)
	if (data[j] < ' ' || data[j] > '~')
	  break;
      if (j < i+ll)
	anObject = [CLData dataWithBytes:&data[i] length:ll];
      else
	anObject = [CLString stringWithBytes:(char *) &data[i] length:ll
			     encoding:CLUTF8StringEncoding];
      i += ll;
    }
    break;

  default:
    break;
  }

  *pos = i;
  return anObject;
}

-(id) bDecode
{
  CLUInteger i;


  i = 0;
  return [self decodeBObject:&i];
}

-(CLString *) hexEncode
{
  CLUInteger i;
  CLMutableString *mString;

  
  mString = [CLMutableString string];
  for (i = 0; i < len; i++)
    [mString appendFormat:@"%02x", data[i]];
  return mString;
}

-(CLUInteger) crc32
{
  static const unsigned long crcTable[256] = {
    0x00000000,0x77073096,0xEE0E612C,0x990951BA,0x076DC419,0x706AF48F,0xE963A535,
    0x9E6495A3,0x0EDB8832,0x79DCB8A4,0xE0D5E91E,0x97D2D988,0x09B64C2B,0x7EB17CBD,
    0xE7B82D07,0x90BF1D91,0x1DB71064,0x6AB020F2,0xF3B97148,0x84BE41DE,0x1ADAD47D,
    0x6DDDE4EB,0xF4D4B551,0x83D385C7,0x136C9856,0x646BA8C0,0xFD62F97A,0x8A65C9EC,
    0x14015C4F,0x63066CD9,0xFA0F3D63,0x8D080DF5,0x3B6E20C8,0x4C69105E,0xD56041E4,
    0xA2677172,0x3C03E4D1,0x4B04D447,0xD20D85FD,0xA50AB56B,0x35B5A8FA,0x42B2986C,
    0xDBBBC9D6,0xACBCF940,0x32D86CE3,0x45DF5C75,0xDCD60DCF,0xABD13D59,0x26D930AC,
    0x51DE003A,0xC8D75180,0xBFD06116,0x21B4F4B5,0x56B3C423,0xCFBA9599,0xB8BDA50F,
    0x2802B89E,0x5F058808,0xC60CD9B2,0xB10BE924,0x2F6F7C87,0x58684C11,0xC1611DAB,
    0xB6662D3D,0x76DC4190,0x01DB7106,0x98D220BC,0xEFD5102A,0x71B18589,0x06B6B51F,
    0x9FBFE4A5,0xE8B8D433,0x7807C9A2,0x0F00F934,0x9609A88E,0xE10E9818,0x7F6A0DBB,
    0x086D3D2D,0x91646C97,0xE6635C01,0x6B6B51F4,0x1C6C6162,0x856530D8,0xF262004E,
    0x6C0695ED,0x1B01A57B,0x8208F4C1,0xF50FC457,0x65B0D9C6,0x12B7E950,0x8BBEB8EA,
    0xFCB9887C,0x62DD1DDF,0x15DA2D49,0x8CD37CF3,0xFBD44C65,0x4DB26158,0x3AB551CE,
    0xA3BC0074,0xD4BB30E2,0x4ADFA541,0x3DD895D7,0xA4D1C46D,0xD3D6F4FB,0x4369E96A,
    0x346ED9FC,0xAD678846,0xDA60B8D0,0x44042D73,0x33031DE5,0xAA0A4C5F,0xDD0D7CC9,
    0x5005713C,0x270241AA,0xBE0B1010,0xC90C2086,0x5768B525,0x206F85B3,0xB966D409,
    0xCE61E49F,0x5EDEF90E,0x29D9C998,0xB0D09822,0xC7D7A8B4,0x59B33D17,0x2EB40D81,
    0xB7BD5C3B,0xC0BA6CAD,0xEDB88320,0x9ABFB3B6,0x03B6E20C,0x74B1D29A,0xEAD54739,
    0x9DD277AF,0x04DB2615,0x73DC1683,0xE3630B12,0x94643B84,0x0D6D6A3E,0x7A6A5AA8,
    0xE40ECF0B,0x9309FF9D,0x0A00AE27,0x7D079EB1,0xF00F9344,0x8708A3D2,0x1E01F268,
    0x6906C2FE,0xF762575D,0x806567CB,0x196C3671,0x6E6B06E7,0xFED41B76,0x89D32BE0,
    0x10DA7A5A,0x67DD4ACC,0xF9B9DF6F,0x8EBEEFF9,0x17B7BE43,0x60B08ED5,0xD6D6A3E8,
    0xA1D1937E,0x38D8C2C4,0x4FDFF252,0xD1BB67F1,0xA6BC5767,0x3FB506DD,0x48B2364B,
    0xD80D2BDA,0xAF0A1B4C,0x36034AF6,0x41047A60,0xDF60EFC3,0xA867DF55,0x316E8EEF,
    0x4669BE79,0xCB61B38C,0xBC66831A,0x256FD2A0,0x5268E236,0xCC0C7795,0xBB0B4703,
    0x220216B9,0x5505262F,0xC5BA3BBE,0xB2BD0B28,0x2BB45A92,0x5CB36A04,0xC2D7FFA7,
    0xB5D0CF31,0x2CD99E8B,0x5BDEAE1D,0x9B64C2B0,0xEC63F226,0x756AA39C,0x026D930A,
    0x9C0906A9,0xEB0E363F,0x72076785,0x05005713,0x95BF4A82,0xE2B87A14,0x7BB12BAE,
    0x0CB61B38,0x92D28E9B,0xE5D5BE0D,0x7CDCEFB7,0x0BDBDF21,0x86D3D2D4,0xF1D4E242,
    0x68DDB3F8,0x1FDA836E,0x81BE16CD,0xF6B9265B,0x6FB077E1,0x18B74777,0x88085AE6,
    0xFF0F6A70,0x66063BCA,0x11010B5C,0x8F659EFF,0xF862AE69,0x616BFFD3,0x166CCF45,
    0xA00AE278,0xD70DD2EE,0x4E048354,0x3903B3C2,0xA7672661,0xD06016F7,0x4969474D,
    0x3E6E77DB,0xAED16A4A,0xD9D65ADC,0x40DF0B66,0x37D83BF0,0xA9BCAE53,0xDEBB9EC5,
    0x47B2CF7F,0x30B5FFE9,0xBDBDF21C,0xCABAC28A,0x53B39330,0x24B4A3A6,0xBAD03605,
    0xCDD70693,0x54DE5729,0x23D967BF,0xB3667A2E,0xC4614AB8,0x5D681B02,0x2A6F2B94,
    0xB40BBE37,0xC30C8EA1,0x5A05DF1B,0x2D02EF8D };
  unsigned long crc32;
  unsigned long inCrc32 = 0;
  CLUInteger i;
  

  /** accumulate crc32 for buffer **/
  crc32 = inCrc32 ^ 0xFFFFFFFF;
  for (i = 0; i < len; i++)
    crc32 = (crc32 >> 8) ^ crcTable[(crc32 ^ data[i]) & 0xFF];
  return crc32 ^ 0xFFFFFFFF;
}

-(CLData *) md5
{
  unsigned char *mdbuf;

  
  mdbuf = MD5(data, len, NULL);
  return [CLData dataWithBytes:mdbuf length:MD5_DIGEST_LENGTH];
}

-(CLData *) hmacSHA1WithKey:(CLData *) aKey
{
  unsigned char *hmacbuf;
  unsigned int mdlen;


  hmacbuf = HMAC(EVP_sha1(), [aKey bytes], [aKey length], data, len, NULL, &mdlen);
  return [CLData dataWithBytes:hmacbuf length:mdlen];
}

-(CLArray *) enumerateDirectory:(CLString *) path
{
  CLString *directory, *filename;
  CLMutableArray *backups = nil;
  int fnLen, deLen;
  DIR *dir;
  struct dirent *dirp;
  const char *fn;
  

  directory = [path stringByDeletingLastPathComponent];
  filename = [path lastPathComponent];
  fn = [filename UTF8String];
  
  if ((dir = opendir([directory UTF8String]))) {
    fnLen = strlen(fn);
    while ((dirp = readdir(dir))) {
      deLen = strlen(dirp->d_name);
      if (deLen > fnLen && dirp->d_name[fnLen] == '.' && dirp->d_name[fnLen+1] == '~' &&
	  dirp->d_name[deLen-1] == '~' && !strncmp(fn, dirp->d_name, fnLen)) {
	if (!backups)
	  backups = [CLMutableArray array];
	[backups addObject:[CLString stringWithUTF8String:dirp->d_name]];
      }
    }
  }

  return backups;
}

-(CLUInteger) highestBackup:(CLArray *) backups
{
  int i, j, k, l;
  CLString *aString;


  for (i = k = 0, j = [backups count]; i < j; i++) {
    aString = [backups objectAtIndex:i];
    aString = [aString pathExtension];
    l = [[aString substringFromIndex:1] intValue];
    if (l > k)
      k = l;
  }

  return k;
}

-(BOOL) writeToFile:(CLString *) path atomically:(BOOL) atomic
    preserveBackups:(CLUInteger) numBackups
{
  CLString *writePath, *backupPath = nil;
  size_t written;
  int i, j;
  int err = 1;
  CLArray *backups;
  struct stat st;
  int fd;
  

  if (numBackups)
    atomic = YES;
  
  if (!atomic)
    writePath = path;
  else
    writePath = [path stringByAppendingPathExtension:
			[CLString stringWithFormat:@"%i", getpid()]];

  if ((fd = open([writePath UTF8String], O_WRONLY | O_TRUNC | O_CREAT, 0644)) < 0)
    return NO;
  
  written = write(fd, data, len);
  close(fd);

  if (written == len) {
    if (numBackups) {
      backups = [self enumerateDirectory:path];
      if ([backups count] > numBackups - 1) {
	for (i = 2, j = [backups count] - 1; i < j; i++)
	  unlink([[backups objectAtIndex:i] UTF8String]);
      }

      backupPath = [path stringByAppendingPathExtension:
			   [CLString stringWithFormat:@"~%i~",
				     [self highestBackup:backups] + 1]];
      unlink([backupPath UTF8String]);
    }
    
    if (stat([path UTF8String], &st) ||
	(!numBackups || (!link([path UTF8String], [backupPath UTF8String]) &&
			  !unlink([path UTF8String])))) {
      if (!link([writePath UTF8String], [path UTF8String]))
	err = 0;
    }
  }

  if (atomic)
    unlink([writePath UTF8String]);
  
  return !err && written == len;
}

#if DEBUG_RETAIN
#undef copy
#undef retain
-(id) copy:(const char *) file :(int) line :(id) retainer
{
  return [self retain:file :line :retainer];
}
#else
-(id) copy
{
  return [self retain];
}
#endif

@end
