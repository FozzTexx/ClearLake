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

#import "CLOriginalFile.h"
#import "CLData.h"
#import "CLInput.h"
#import "CLMutableDictionary.h"
#import "CLManager.h"
#import "CLControl.h"
#import "CLCharacterSet.h"
#import "CLHashTable.h"
#import "CLStandardContent.h"
#import "CLClassConstants.h"

#include <sys/stat.h>
#include <unistd.h>
#include <stdlib.h>

/* FIXME - some kind of bug in the linker where it ignores everything
   in a .m file that isn't explicitly named in other source. */
#import "CLStandardContentFile.m"

#define FILE_CMD	@"/usr/local/bin/file"

@implementation CLOriginalFile

+(id) fileFromField:(CLInput *) aField table:(CLString *) aTable
{
  CLOriginalFile *aFile;
  id aValue;


  aValue = [aField value];
  if ([aValue isKindOfClass:self])
    return aValue;
  else if ([aValue isKindOfClass:CLOriginalFileClass])
    aValue = [aValue data];

  if ([aValue isKindOfClass:CLDataClass]) {
    aFile = [self fileFromData:aValue table:aTable];
    [aFile setFilename:[[aField attributes] objectForKey:@"filename"]];
    return aFile;
  }

  return nil;
}

+(id) fileFromFile:(CLString *) aFilename table:(CLString *) aTable
{
  CLOriginalFile *aFile = nil;


  aFile = [[self alloc] initFromDictionary:nil table:aTable];
  [aFile setFilename:[aFilename lastPathComponent]];

  return aFile;
}

+(id) fileFromData:(CLData *) aData table:(CLString *) aTable
{
  return [[[self alloc] initFromData:aData table:aTable] autorelease];
}

+(id) fileFromPath:(CLString *) aPath table:(CLString *) aTable hardlink:(BOOL) hardlink
{
  int oid;
  CLString *dbPath;
  CLOriginalFile *aFile = nil;
  CLData *aData;

  
  if (hardlink) {
    oid = CLStoreFile(nil, [aPath pathExtension], nil);
    if ((dbPath = CLPathForFileID(oid))) {
      unlink([dbPath UTF8String]);
      if (!link([aPath UTF8String], [dbPath UTF8String])) {
	aFile = [[self alloc] initFromDictionary:nil table:aTable];
	[aFile setObjectID:oid];
      }
    }
  }
  else if ((aData = [CLData dataWithContentsOfFile:aPath]))
    aFile = [self fileFromData:aData table:aTable];

  return aFile;
}

-(id) init
{
  return [self initFromData:nil table:nil];
}

-(id) initFromData:(CLData *) aData table:(CLString *) aTable
{
  if (aTable)
    [super initFromDictionary:nil table:aTable];
  else
    [super init];
  data = [aData copy];
  loaded = !!data;
  _filename = nil;
  return self;
}

-(void) dealloc
{
  [data release];
  [_filename release];
  [super dealloc];
  return;
}

-(id) read:(CLStream *) stream
{
  [super read:stream];
  loaded = NO;
  data = nil;
  return self;
}

-(void) write:(CLStream *) stream
{
  [super write:stream];
  return;
}

-(int) objectID
{
  /* FIXME - just update the sequence number, don't have to actually write to disk */
  if (![super objectID])
    [self save];
  return [super objectID];
}

-(CLString *) path
{
  return CLPathForFileID([self objectID]);
}

-(void) load
{
  if (!loaded) {
    data = [CLData dataWithContentsOfFile:[self path]];
    loaded = YES;
  }

  return;
}

-(BOOL) save
{
  int oid;
  CLString *aString = [self filename];

  
  if (![super objectID] && loaded) {
    if ((oid = CLStoreFile(data, nil, [aString pathExtension])))
      [self setObjectID:oid];
    else
      return NO;
  }
  return YES;
}
  
-(unsigned long long) bytes
{
  unsigned long long l = 0;
  struct stat st;


  if (!stat([[self path] UTF8String], &st))
    l = st.st_size;

  return l;
}

-(CLData *) data
{
  [self load];
  return data;
}

-(CLString *) generateURL
{
#if 0
  CLString *path;
  const char *p;
#endif
  CLString *aString = nil;
  CLControl *aControl;


#if 0
  path = [self path];

  if ((p = getenv("DOCUMENT_ROOT")))
    aString = [CLString stringWithUTF8String:p];
  else
    aString = [CLString stringWithString:CLAppPath];
#endif

  /* Always want to generate a URL so that when the user downloads we
     can stick the original filename on */
#if 0  
  if (![path hasPrefix:aString] ||
      [path characterAtIndex:[aString length]] != '/') {
#endif
    aControl = [[CLControl alloc] init];
    [aControl setTarget:self];
    [aControl setAction:@selector(download:)];
    aString = [aControl generateURL];
    [aControl release];
#if 0
  }
  else {
    CLString *prefix, *filename;
    
    
    prefix = [path substringFromIndex:[aString length]];
    filename = [prefix lastPathComponent];
    prefix = [prefix stringByDeletingLastPathComponent];
    aString = [prefix stringByAppendingPathComponent:
			[filename stringByAddingPercentEscapes]];
  }
#endif

  return aString;
}

-(CLString *) mimeType
{
  CLString *mimeType = nil, *aPath;
  CLStream *tFile = nil;


  if (![super objectID]) {
    tFile = [CLStream openTemporaryFile:@"file.XXXXXX"];
    [tFile writeData:data];
    [tFile close];
    aPath = [tFile path];
  }
  else
    aPath = CLPathForFileID([self objectID]);

  mimeType = [CLStream mimeTypeForFile:aPath];
  [tFile remove];
  
  if (!mimeType)
    mimeType = @"application/octet-stream";
  return mimeType;
}

-(void) download:(id) sender
{
  printf("Status: 200\n");
  printf("Content-Type: %s\n", [[self mimeType] UTF8String]);
  printf("Content-Length: %llu\n", [self bytes]);
  printf("Content-Disposition: attachment; filename=\"%s\"\n", [[self filename] UTF8String]);
  printf("\n");

  [self load];
  fwrite([data bytes], 1, [data length], stdout);
  fflush(stdout);

  /* Normally the program should exit here but let caller handle it in
     case they want to do some logging or cleanup. */
  return;
}

-(void) view:(id) sender
{
  printf("Status: 200\n");
  printf("Content-Type: %s\n", [[self mimeType] UTF8String]);
  printf("Content-Length: %llu\n", [self bytes]);
  printf("Content-Disposition: filename=\"%s\"\n", [[self filename] UTF8String]);
  printf("\n");

  [self load];
  fwrite([data bytes], 1, [data length], stdout);
  fflush(stdout);
  return;
}

-(BOOL) isAudio
{
  CLString *aString = [self mimeType];


  if ([aString hasPrefix:@"audio/"])
    return YES;
  return NO;
}

-(BOOL) isVideo
{
  CLString *aString = [self mimeType];


  if ([aString hasPrefix:@"video/"])
    return YES;
  return NO;
}

-(BOOL) isFlashVideo
{
  CLString *aString = [self mimeType];


  if ([aString isEqualToString:@"video/x-flv"])
    return YES;
  return NO;
}

-(BOOL) isImage
{
  CLString *aString = [self mimeType];


  if ([aString hasPrefix:@"image/"])
    return YES;
  return NO;
}

-(BOOL) isPDF
{
  CLString *aString = [self mimeType];


  if ([aString isEqualToString:@"application/pdf"])
    return YES;
  return NO;
}
  
-(CLString *) filename
{
  if ([self hasFieldNamed:@"filename"])
    return CLHashTableDataForKey(_record, @"filename", [@"filename" hash],
				 @selector(isEqual:));
  return _filename;
}

-(void) setFilename:(CLString *) aString
{
  if ([self hasFieldNamed:@"filename"])
    [self setObjectValue:aString forVariable:@"filename"];
  else {
    [_filename release];
    _filename = [aString copy];
  }
  return;
}

-(void) didDeleteFromDatabase
{
  [super didDeleteFromDatabase];
  unlink([CLPathForFileID([super objectID]) UTF8String]);
  return;
}

-(void) willSaveToDatabase
{
  [self save];
  [super willSaveToDatabase];
  return;
}

@end
