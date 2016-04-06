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

#import "CLImageRep.h"
#import "CLString.h"
#import "CLStream.h"
#import "CLMutableData.h"
#import "CLArray.h"

#include <dirent.h>
#include <fcntl.h>
#include <piclib/piclib.h>
#include <piclib/picloader.h>
#include <piclib/picsaver.h>
#include <stdlib.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>
#include <wctype.h>
#include <math.h>
#include <string.h>

#define IMAGE_DIR	@"imagedb"

@implementation CLImageRep

+(CLImageRep *) imageRepFromFile:(CLString *) filename
{
  return [[[self alloc] initFromFile:filename] autorelease];
}

+(CLImageRep *) imageRepFromData:(CLData *) aData
{
  return [[[self alloc] initFromData:aData] autorelease];
}

-(id) init
{
  return [self initFromFile:nil];
}

-(id) initFromFile:(CLString *) filename
{
  [super init];
  rep = NULL;
  path = nil;

  if (filename)
    path = [filename copy];

  return self;
}

-(id) initFromData:(CLData *) aData
{
  CLStream *oFile;
  CLImageRep *aRep;


  /* FIXME - this is gross having to write a file to read it back in */
  if (!(oFile = [CLStream openTemporaryFile:@"climagerepXXXXXX"])) {
    [super init];
    [self release];
    return nil;
  }

  [oFile writeData:aData];
  [oFile close];
  aRep = [self initFromFile:[oFile path]];
  [oFile remove];
  return aRep;
}

-(void) dealloc
{
  if (rep) {
    freeImage(rep);
    free(rep);
  }
  [path release];
  [super dealloc];
  return;
}

-(id) read:(CLStream *) stream
{
  id anObject;
  CLImageRep *aRep;

  
  [super read:stream];
  [stream readTypes:@"@", &anObject];
  if ([anObject isKindOfClass:CLStringClass]) {
    path = anObject;
    if (!(rep = malloc(sizeof(image))))
      [self error:@"Unable to allocate memory"];
    rep = NULL;
  }
  else {
    path = nil;
    aRep = [[CLImageRep alloc] initFromData:anObject];
    rep = [aRep piclibCopy];
    [aRep release];
  }
    
  return self;
}

-(void) write:(CLStream *) stream
{
  CLData *aData;

  
  [super write:stream];
  if (path)
    [stream writeTypes:@"@", &path];
  else {
    aData = [self representationUsingFormat:@"png"];
    [stream writeTypes:@"@", &aData];
  }
  
  return;
}

-(CLSize) size
{
  image *aRep;
  imageInfo info;
  int err;


  if ((aRep = rep))
    return CLMakeSize(aRep->width, aRep->height);
  else if (path && !(err = getImageInfo([path UTF8String], &info)))
    return CLMakeSize(info.width, info.height);
    
  return CLMakeSize(0, 0);
}

-(void) clearPath
{
  [path release];
  path = nil;
  return;
}

-(CLString *) path
{
  return path;
}

-(void *) loadImage
{
  int err;
  image *aRep;


  if (!rep && path) {
    if (!(aRep = calloc(1, sizeof(image))))
      [self error:@"Unable to allocate memory"];
    err = load_pic([path UTF8String], aRep);
    if (err && (err != PICERR_BADFORMAT || !aRep->data)) {
      /* FIXME - somehow indicate the exact error to the caller */
      free(aRep);
      return NULL;
    }

    rep = aRep;
  }

  return rep;
}

-(void) scaleImage:(CLSize) aSize blend:(BOOL) flag
{
  image *aRep;


  if (!(aRep = [self loadImage]))
    return;

  resizeImage(aSize.width, aSize.height, flag, aRep);
  [self clearPath];

  return;
}

-(void) cropImage:(CLRect) aRect
{
  if (!rep)
    return;
  cropImage(aRect.origin.x, aRect.origin.y,
	    aRect.origin.x + aRect.size.width - 1,
	    aRect.origin.y + aRect.size.height - 1, rep);
  [self clearPath];
  return;
}

-(void) autocropImage:(int) margin
{
  autoCropImage(rep, margin);
  [self clearPath];
  return;
}

-(void) zoomImage:(CLSize) mSize blend:(BOOL) blend slideTo:(CLString *) direction
{
  CLSize nSize, cSize;
  CLRect aRect;
  int xdir = 0, ydir = 0;
  CLRange aRange;
  int c;


  if ([direction length]) {
    aRange.location = 0;
    aRange.length = 1;
    while (aRange.length) {
      c = [direction characterAtIndex:aRange.location];
      if (c == 'r')
	xdir = 1;
      if (c == 'l')
	xdir = -1;
      if (c == 'b')
	ydir = 1;
      if (c == 't')
	ydir = -1;

      aRange.location = CLMaxRange(aRange);
      aRange.length = [direction length] - aRange.location;
      if (aRange.length) {
	aRange = [direction rangeOfString:@"+" options:0 range:aRange];
	if (aRange.length) {
	  aRange.location = CLMaxRange(aRange);
	  if (aRange.location < [direction length])
	    aRange.length = 1;
	  else
	    aRange.length = 0;
	}
      }
    }
  }
  
  nSize = cSize = [self size];
  if (!mSize.height && mSize.width) {
    nSize.width = mSize.width;
    nSize.height = cSize.height * (mSize.width / cSize.width);
  }
  else if (mSize.height) {
    nSize.height = mSize.height;
    nSize.width = cSize.width * (mSize.height / cSize.height);
    if (mSize.width && nSize.width < mSize.width) {
      nSize.width = mSize.width;
      nSize.height = cSize.height * (mSize.width / cSize.width);
    }
  }
  [self scaleImage:nSize blend:blend];
  cSize = nSize;

  if (mSize.width && mSize.width < nSize.width)
    nSize.width = mSize.width;
  if (mSize.height && mSize.height < nSize.height)
    nSize.height = mSize.height;
  if (cSize.width != nSize.width || cSize.height != nSize.height) {
    aRect.origin.x = (cSize.width - nSize.width) / 2;
    if (xdir) {
      if (xdir > 0)
	aRect.origin.x = cSize.width - nSize.width;
      else if (xdir < 0)
	aRect.origin.x = 0;
    }

    aRect.origin.y = (cSize.height - nSize.height) / 2;
    if (ydir) {
      if (ydir > 0)
	aRect.origin.y = cSize.height - nSize.height;
      else if (ydir < 0)
	aRect.origin.y = 0;
    }
    
    aRect.size = nSize;
    [self cropImage:aRect];
  }

  return;
}

-(void) composite:(CLImageRep *) aRep from:(CLRect) aRect to:(CLPoint) aPoint
{
  int x, y;
  image *dest, *src;
  double vs, vd, as, ad;
  int col = 0, scol, dcol;
  BOOL needFree = NO;
  image newPic;
  

  dest = [self loadImage];
  src = [aRep loadImage];

  if ((dest->photoInterp & MONOMASK) && !(src->photoInterp & MONOMASK)) {
    needFree = YES;
    copyImage(&newPic, src);
    makeMono(&newPic);
    src = &newPic;
  }

  scol = src->samplesPerPixel;
  if (src->photoInterp & ALPHAMASK)
    scol--;
  dcol = dest->samplesPerPixel;
  if (dest->photoInterp & ALPHAMASK)
    dcol--;
  for (y = 0; y < aRect.size.height; y++) {
    for (x = 0; x < aRect.size.width; x++) {
      as = ad = 1.0;
      if (src->photoInterp & ALPHAMASK)
	as = getval(x + aRect.origin.x, y + aRect.origin.y, scol, src) / 255.0;
      if (dest->photoInterp & ALPHAMASK)
	ad = getval(x + aPoint.x, y + aPoint.y, dcol, dest) / 255.0;

      if (scol == dcol) {
	for (col = 0; col < scol; col++) {
	  vs = getval(x + aRect.origin.x, y + aRect.origin.y, col, src) / 255.0;
	  vd = getval(x + aPoint.x, y + aPoint.y, col, dest) / 255.;

	  vd = vs * as + vd * ad * (1.0 - as);
	  putval(x + aPoint.x, y + aPoint.y, vd * 255, col, dest);
	}
      }
      else if (scol < dcol) {
	vs = getval(x + aRect.origin.x, y + aRect.origin.y, col, src) / 255.0;
	vd = getval(x + aPoint.x, y + aPoint.y, col, dest) / 255.0;

	vd = vs * as + vd * ad * (1.0 - as);
	for (col = 0; col < dcol; col++)
	  putval(x + aPoint.x, y + aPoint.y, vd * 255, col, dest);
      }

      if (dest->photoInterp & ALPHAMASK) {
	ad = as + ad * (1.0 - as);
	putval(x + aPoint.x, y + aPoint.y, ad * 255, dcol, dest);
      }	
    }
  }

  if (needFree)
    freeImage(&newPic);

  [self clearPath];
  return;
}

-(void) rotate:(double) radians;
{
  rotateImage(rep, radians);
  return;
}

-(BOOL) writeToFile:(CLString *) filename format:(CLString *) format
{
  if (save_pic([filename UTF8String], [format UTF8String], rep))
    return NO;
  return YES;
}

-(CLData *) representationUsingFormat:(CLString *) format
{
  CLStream *oFile;
  const char *tpath;
  CLData *aData = nil;
  CLString *saveFormat = format;
  CLMutableData *mData;
  CLString *cmd;
  char buf[4096];
  size_t len;


  if ((oFile = [CLStream openTemporaryFile:@"climage.XXXXXX"])) {
    [oFile close];
    tpath = [[oFile path] UTF8String];

    if ([saveFormat isEqualToString:@"eps"])
      saveFormat = @"png";
    [self loadImage];
    if (!save_pic(tpath, [saveFormat UTF8String], rep)) {
      if ([format isEqualToString:@"eps"]) {
	cmd = [CLString stringWithFormat:@"/usr/bin/convert %@ eps:-", [oFile path]];
	oFile = [CLStream openPipe:cmd mode:CLReadOnly];
	mData = [CLMutableData data];
	while ((len = [oFile read:buf length:sizeof(buf)]))
	  [mData appendBytes:buf length:len];
	[oFile closeAndWait];
	aData = mData;
      }
      else
	aData = [CLData dataWithContentsOfFile:[oFile path]];
    }

    unlink(tpath);
  }

  return aData;
}

-(void) doEffect:(CLString *) aString
{
  CLArray *anArray, *args = nil;
  CLString *effect;


  anArray = [aString componentsSeparatedByString:@"="];
  effect = [anArray objectAtIndex:0];
  if ([anArray count] > 1)
    args = [[anArray objectAtIndex:1] componentsSeparatedByString:@","];

  if ([effect isEqualToString:@"maxsize"] ||
      [effect isEqualToString:@"minsize"]) {
    CLSize cSize, mSize, nSize;
    CLString *aString;
    BOOL blend = NO;


    cSize = [self size];
    nSize = mSize = CLMakeSize(0, 0);
    if ([(aString = [args objectAtIndex:0]) length])
      mSize.width = [aString intValue];
    if ([args count] > 1 && [(aString = [args objectAtIndex:1]) length])
      mSize.height = [aString intValue];
    if ([args count] > 2 && [(aString = [args objectAtIndex:2]) length])
      blend = [aString boolValue];

    if ([effect isEqualToString:@"maxsize"] &&
	((mSize.width && cSize.width > mSize.width) ||
	 (mSize.height && cSize.height > mSize.height))) {
      if (!mSize.height && mSize.width) {
	nSize.width = mSize.width;
	nSize.height = cSize.height * (mSize.width / cSize.width);
      }
      else if (mSize.height) {
	nSize.height = mSize.height;
	nSize.width = cSize.width * (mSize.height / cSize.height);
	if (mSize.width && nSize.width > mSize.width) {
	  nSize.width = mSize.width;
	  nSize.height = cSize.height * (mSize.width / cSize.width);
	}
      }

      [self scaleImage:nSize blend:blend];
    }
    else if ([effect isEqualToString:@"minsize"] &&
	((mSize.width && cSize.width < mSize.width) ||
	 (mSize.height && cSize.height < mSize.height))) {
      if (!mSize.height && mSize.width) {
	nSize.width = mSize.width;
	nSize.height = cSize.height * (mSize.width / cSize.width);
      }
      else if (mSize.height) {
	nSize.height = mSize.height;
	nSize.width = cSize.width * (mSize.height / cSize.height);
	if (mSize.width && nSize.width < mSize.width) {
	  nSize.width = mSize.width;
	  nSize.height = cSize.height * (mSize.width / cSize.width);
	}
      }

      [self scaleImage:nSize blend:blend];
    }
  }
  else if ([effect isEqualToString:@"centercrop"]) {
    CLSize cSize, mSize, nSize;
    CLRect aRect;
    CLString *aString;


    nSize = cSize = [self size];
    mSize = CLMakeSize(0, 0);
    if ([(aString = [args objectAtIndex:0]) length])
      mSize.width = [aString intValue];
    if ([args count] > 1 && [(aString = [args objectAtIndex:1]) length])
      mSize.height = [aString intValue];

    if (mSize.width && mSize.width < nSize.width)
      nSize.width = mSize.width;
    if (mSize.height && mSize.height < nSize.height)
      nSize.height = mSize.height;
    if (cSize.width != nSize.width || cSize.height != nSize.height) {
      aRect.origin.x = (cSize.width - nSize.width) / 2;
      aRect.origin.y = (cSize.height - nSize.height) / 2;
      aRect.size = nSize;
      [self cropImage:aRect];
    }
  }
  else if ([effect isEqualToString:@"crop"]) {
    CLRect aRect;


    aRect = CLMakeRect([[args objectAtIndex:0] intValue], [[args objectAtIndex:1] intValue],
		       [[args objectAtIndex:2] intValue], [[args objectAtIndex:3] intValue]);
    [self cropImage:aRect];
  }
  else if ([effect isEqualToString:@"autocrop"]) {
    int margin = 40;

    
    if ([args count])
      margin = [[args objectAtIndex:0] intValue];
    [self autocropImage:margin];
  }
  else if ([effect isEqualToString:@"size"]) {
    CLSize aSize;
    BOOL blend = NO;


    aSize = CLMakeSize([[args objectAtIndex:0] intValue], [[args objectAtIndex:1] intValue]);
    if ([args count] > 2 && [(aString = [args objectAtIndex:2]) length])
      blend = [aString boolValue];
    [self scaleImage:aSize blend:blend];
  }
  else if ([effect isEqualToString:@"zoom"]) {
    CLSize mSize;
    CLString *aString;
    BOOL blend = NO;


    mSize = CLMakeSize(0, 0);
    if ([(aString = [args objectAtIndex:0]) length])
      mSize.width = [aString intValue];
    if ([args count] > 1 && [(aString = [args objectAtIndex:1]) length])
      mSize.height = [aString intValue];
    if ([args count] > 2 && [(aString = [args objectAtIndex:2]) length])
      blend = [aString boolValue];
    if ([args count] <= 3 || ![(aString = [args objectAtIndex:3]) length])
      aString = nil;
    [self zoomImage:mSize blend:blend slideTo:aString];
  }
  else if ([effect isEqualToString:@"format"]) {
    CLString *format;
    formatInfo info;


    format = [[args objectAtIndex:0] lowercaseString];
    if (infoForFormat([format UTF8String], &info) == PICERR_FORMATNOTSUPPORTED)
      format = @"png";
    if (![path length])
      path = @"Image";
    [path autorelease];
    path = [[[path stringByDeletingPathExtension] stringByAppendingPathExtension:format]
	     retain];
  }

  return;
}

-(CLImageRep *) imageRepFromEffects:(CLString *) effects
{
  CLArray *anArray;
  int i, j;
  CLImageRep *newRep;


  if (![self loadImage])
    return nil;
  
  newRep = [self copy];
  anArray = [effects componentsSeparatedByString:@";"];
  for (i = 0, j = [anArray count]; i < j; i++)
    [newRep doEffect:[anArray objectAtIndex:i]];

  return [newRep autorelease];
}

-(id) imageRep
{
  return self;
}

-(CLString *) bestFormat
{
  CLString *format = [[path pathExtension] lowercaseString];


  if (![format length] || [format isEqualToString:@"gif"])
    format = @"png";
  if ([format isEqualToString:@"jpeg"])
    format = @"jpg";
  
  return format;
}

-(void *) piclibCopy
{
  image *img;


  if (!(img = malloc(sizeof(image))))
    [self error:@"Unable to allocate memory"];
  copyImage(img, [self loadImage]);
  return img;
}

-(id) initFromPiclib:(void *) aPic
{
  [super init];
  path = nil;
  rep = malloc(sizeof(image));
  copyImage(rep, aPic);
  return self;
}

#if DEBUG_RETAIN
#undef copy
-(id) copy:(const char *) file :(int) line :(id) retainer
{
  CLImageRep *aCopy;
  void *anImage;


  aCopy = [super copy:file :line: retainer];
#define copy		copy:__FILE__ :__LINE__ :self
  aCopy->path = [path copy];
  if ((anImage = [self loadImage])) {
    if (!(aCopy->rep = malloc(sizeof(image))))
      [self error:@"Unable to allocate memory"];
    copyImage(aCopy->rep, anImage);
  }
  return aCopy;
}
#else
-(id) copy
{
  CLImageRep *aCopy;
  void *anImage;


  aCopy = [super copy];
  aCopy->path = [path copy];
  if ((anImage = [self loadImage])) {
    if (!(aCopy->rep = malloc(sizeof(image))))
      [self error:@"Unable to allocate memory"];
    copyImage(aCopy->rep, anImage);
  }
  return aCopy;
}
#endif

@end

CLString *CLPathForImageID(int image_id)
{
  CLString *aPath;
  DIR *dir;
  struct dirent *dp;
  int i;
  char buf[20];


  aPath = [CLString stringWithFormat:@"%s/%@/%i/%i",
		    getenv("DOCUMENT_ROOT"), IMAGE_DIR,
		    image_id % 10, (image_id / 10) % 10];
  sprintf(buf, "%i", image_id);

  if ((dir = opendir([aPath UTF8String]))) {
    i = strlen(buf);
    for (dp = readdir(dir); dp; dp = readdir(dir))
      if (dp->d_name[0] != '.' && strlen(dp->d_name) > i && dp->d_name[i] == '.' &&
	  !strncmp(buf, dp->d_name, i)) {
	aPath = [aPath stringByAppendingPathComponent:
			 [CLString stringWithUTF8String:dp->d_name]];
	break;
      }
    closedir(dir);

    if (!dp || access([aPath UTF8String], R_OK))
      aPath = nil;
  }
  else
    aPath = nil;

  if (!aPath)
    aPath = CLPathForFileID(image_id);
  
  return aPath;
}

int CLStoreImage(CLData *aData)
{
  CLStream *oFile;
  CLString *extension = nil;
  imageInfo info;


  if ((oFile = [CLStream openTemporaryFile:@"climageXXXXXX"])) {
    [oFile writeData:aData];
    [oFile close];

    if (!getImageInfo([[oFile path] UTF8String], &info))
      extension = [CLString stringWithUTF8String:info.extension];
    [oFile remove];

    if (extension)
      return CLStoreFile(aData, extension, nil);
  }

  return 0;
}
