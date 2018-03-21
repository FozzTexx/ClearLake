/* Copyright 1995-2007 by Chris Osborn <fozztexx@fozztexx.com>
 *
 * Copyright 2008-2016 by
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

#import "CLPage.h"
#import "CLPageStack.h"
#import "CLPageObject.h"
#import "CLAutoreleasePool.h"
#import "CLElement.h"
#import "CLControl.h"
#import "CLMutableString.h"
#import "CLRange.h"
#import "CLMutableDictionary.h"
#import "CLCookie.h"
#import "CLMutableArray.h"
#import "CLBlock.h"
#import "CLImageElement.h"
#import "CLForm.h"
#import "CLInput.h"
#import "CLButton.h"
#import "CLTextArea.h"
#import "CLSelect.h"
#import "CLScriptElement.h"
#import "CLAccount.h"
#import "CLManager.h"
#import "CLSession.h"
#import "CLRangeView.h"
#import "CLPager.h"
#import "CLOption.h"
#import "CLNumber.h"
#import "CLChainedSelect.h"
#import "CLSplitter.h"
#import "CLCharacterSet.h"
#import "CLNull.h"
#import "CLPageTarget.h"
#import "CLData.h"
#import "CLRuntime.h"
#import "CLEditingContext.h"
#import "CLStackString.h"
#import "CLClassConstants.h"

#include <stdlib.h>
#include <ctype.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <wctype.h>
#include <string.h>

#define BUFSIZE		256
#define QUERY_DEBUG	@"CLdbg"

static CLArray *CLPageExtensions = nil;

typedef struct CLStatus {
  CLUInteger status;
  CLString *string;
} CLStatus;

CLStatus CLStatusStrings[] = {
  {100, @"Continue"},
  {101, @"Switching Protocols"},
  {200, @"OK"},
  {201, @"Created"},
  {202, @"Accepted"},
  {203, @"Non-Authoritative Information"},
  {204, @"No Content"},
  {205, @"Reset Content"},
  {206, @"Partial Content"},
  {300, @"Multiple Choices"},
  {301, @"Moved Permanently"},
  {302, @"Found"},
  {303, @"See Other"},
  {304, @"Not Modified"},
  {305, @"Use Proxy"},
  {306, @"Switch Proxy"},
  {307, @"Temporary Redirect"},
  {400, @"Bad Request"},
  {401, @"Unauthorized"},
  {402, @"Payment Required"},
  {403, @"Forbidden"},
  {404, @"Not Found"},
  {405, @"Method Not Allowed"},
  {406, @"Not Acceptable"},
  {407, @"Proxy Authentication Required"},
  {408, @"Request Timeout"},
  {409, @"Conflict"},
  {410, @"Gone"},
  {411, @"Length Required"},
  {412, @"Precondition Failed"},
  {413, @"Request Entity Too Large"},
  {414, @"Request-URI Too Long"},
  {415, @"Unsupported Media Type"},
  {416, @"Requested Range Not Satisfiable"},
  {417, @"Expectation Failed"},
  {500, @"Internal Server Error"},
  {501, @"Not Implemented"},
  {502, @"Bad Gateway"},
  {503, @"Service Unavailable"},
  {504, @"Gateway Timeout"},
  {505, @"HTTP Version Not Supported"},
  {0, nil}
};

CLHashTable *CLPageObjects = NULL;

#if 0
void CLAllowFrom(CLString *aURL)
{
  int i;

  
  if (!validURLs)
    validURLs = [[CLMutableArray alloc] init];
  [validURLs addObject:aURL];
  return;
}

void CLRedirectTo(CLString *aURL)
{
  [redirectTo release];
  redirectTo = [aURL copy];
  return;
}
#endif

BOOL CLBrowserAcceptsGzip()
{
  CLString *aString;
  const char *p, *q;

  
  if ((aString = [CLQuery objectForKey:@"htmlgz"]))
    return [aString boolValue];

  p = getenv("HTTP_ACCEPT_ENCODING");

  while (p && *p) {
    while (*p && isspace(*p))
      p++;
    if (!(q = strchr(p, ',')))
      q = p + strlen(p);
    if (q - p == 4 && !strncmp(p, "gzip", 4))
      return YES;
    p = q;
    if (*p)
      p++;
  }

  return NO;
}

void CLSetDelegate(id anObject)
{
  CLDelegate = anObject;
  return;
}

@implementation CLPage

+(void) linkerIsBorked
{
  [CLChainedSelect linkerIsBorked];
  [CLSplitter linkerIsBorked];
  [CLPageTarget linkerIsBorked];
  return;
}

+(CLPage *) pageFromFile:(CLString *) aFilename owner:(id) anOwner
{
  return [[[[self class] alloc] initFromFile:aFilename owner:anOwner] autorelease];
}

+(CLArray *) pageExtensions
{
  if (!CLPageExtensions)
    CLPageExtensions = [[CLArray alloc]
			 initWithObjects:@"html", @"shtml", @"htm", nil];
  return CLPageExtensions;
}

+(CLString *) findFile:(CLString *) aFilename directory:(CLString *) aDir
{
  CLMutableArray *dirs = nil;
  CLString *aString;


  if (!aFilename)
    return nil;
  
  if (aDir) {
    dirs = [[CLMutableArray alloc] init];
    [dirs addObject:aDir];
  }
  aString = [self findFile:aFilename directories:dirs];
  [dirs release];
  return aString;
}

+(CLString *) findFile:(CLString *) aFilename directories:(CLArray *) dirs
{
  CLString *aString, *path;
  struct stat st;
  CLMutableArray *mArray;
  CLArray *anArray;

  
  if (!CLPageExtensions)
    [self pageExtensions];

  if ([CLDelegate respondsTo:@selector(additionalPageDirectories)] &&
      (anArray = [CLDelegate additionalPageDirectories])) {
    mArray = [CLMutableArray array];
    [mArray addObjectsFromArray:dirs];
    [mArray addObjectsFromArray:anArray];
    dirs = mArray;
  }
  
  path = CLFullPathForFile(aFilename, CLPageExtensions, dirs);

  if ((aString = [CLManager browserType])) {
    if (!path)
      path = CLFullPathForFile(aFilename, CLPageExtensions,
			       [CLArray arrayWithObjects:aString, nil]);
    else {
      aString = [[[path stringByDeletingLastPathComponent]
		   stringByAppendingPathComponent:aString]
		  stringByAppendingPathComponent:[path lastPathComponent]];
      if (!access([aString UTF8String], R_OK))
	path = aString;
    }
  }
  
  
  if (path && (stat([path UTF8String], &st) || S_ISDIR(st.st_mode)))
    path = nil;
  return path;
}

+(void) addPageObject:(CLPageObject *) anObject
{
  CLHashTableSetData(CLPageObjects, [anObject retain], [anObject name], [[anObject name] hash]);
  return;
}

+(CLHashTable *) objectsForTags
{
  if (!CLPageObjects) {
    CLPageObjects = CLHashTableAlloc(CLHashTableDefaultSize);

    [self addPageObject:[CLPageObject objectForName:@"IMG" result:CL_APPEND
					objectClass:CLImageElementClass]];
    [self addPageObject:[CLPageObject objectForName:@"FORM" result:CL_PUSH
					objectClass:CLFormClass]];
    [self addPageObject:[CLPageObject objectForName:@"/FORM" result:CL_POP
					objectClass:nil]];
    [self addPageObject:[CLPageObject objectForName:@"A" result:CL_PUSH
					objectClass:CLControlClass]];
    [self addPageObject:[CLPageObject objectForName:@"/A" result:CL_POP
					objectClass:nil]];
    [self addPageObject:[CLPageObject objectForName:@"SCRIPT" result:CL_PUSH
					objectClass:CLScriptElementClass]];
    [self addPageObject:[CLPageObject objectForName:@"/SCRIPT" result:CL_POP
					objectClass:nil]];

    [self addPageObject:[CLPageObject objectForName:@"INPUT" result:CL_APPEND
					objectClass:CLInputClass]];
    [self addPageObject:[CLPageObject objectForName:@"BUTTON" result:CL_PUSH
					objectClass:CLButtonClass]];
    [self addPageObject:[CLPageObject objectForName:@"/BUTTON" result:CL_POP
					objectClass:nil]];
    [self addPageObject:[CLPageObject objectForName:@"TEXTAREA" result:CL_PUSH
					objectClass:CLTextAreaClass]];
    [self addPageObject:[CLPageObject objectForName:@"/TEXTAREA" result:CL_POP
					objectClass:nil]];
    [self addPageObject:[CLPageObject objectForName:@"SELECT" result:CL_PUSH
					objectClass:CLSelectClass]];
    [self addPageObject:[CLPageObject objectForName:@"/SELECT" result:CL_POP
					objectClass:nil]];

    /* FIXME - this one returns aTag instead of nil */
    [self addPageObject:[CLPageObject objectForName:@"OPTION" result:CL_APPEND
					objectClass:nil]];
    [self addPageObject:[CLPageObject objectForName:@"/OPTION" result:CL_APPEND
					objectClass:nil]];
    [self addPageObject:[CLPageObject objectForName:@"BASE" result:CL_APPEND
					objectClass:nil]];
    
    [self addPageObject:[CLPageObject objectForName:@"LABEL" result:CL_PUSH
					objectClass:nil]];
    [self addPageObject:[CLPageObject objectForName:@"/LABEL" result:CL_POP
					objectClass:nil]];
    [self addPageObject:[CLPageObject objectForName:@"DIV" result:CL_PUSH
					objectClass:nil]];
    [self addPageObject:[CLPageObject objectForName:@"/DIV" result:CL_POP
					objectClass:nil]];
    [self addPageObject:[CLPageObject objectForName:@"SPAN" result:CL_PUSH
					objectClass:nil]];
    [self addPageObject:[CLPageObject objectForName:@"/SPAN" result:CL_POP
					objectClass:nil]];
    [self addPageObject:[CLPageObject objectForName:@"STYLE" result:CL_PUSH
					objectClass:nil]];
    [self addPageObject:[CLPageObject objectForName:@"/STYLE" result:CL_POP
					objectClass:nil]];
    [self addPageObject:[CLPageObject objectForName:@"TABLE" result:CL_PUSH
					objectClass:nil]];
    [self addPageObject:[CLPageObject objectForName:@"/TABLE" result:CL_POP
					objectClass:nil]];
    [self addPageObject:[CLPageObject objectForName:@"TR" result:CL_PUSH
					objectClass:nil]];
    [self addPageObject:[CLPageObject objectForName:@"/TR" result:CL_POP
					objectClass:nil]];
    [self addPageObject:[CLPageObject objectForName:@"TD" result:CL_PUSH
					objectClass:nil]];
    [self addPageObject:[CLPageObject objectForName:@"/TD" result:CL_POP
					objectClass:nil]];
    [self addPageObject:[CLPageObject objectForName:@"TH" result:CL_PUSH
					objectClass:nil]];
    [self addPageObject:[CLPageObject objectForName:@"/TH" result:CL_POP
					objectClass:nil]];

    [self addPageObject:[CLPageObject objectForName:@"UL" result:CL_PUSH
					objectClass:nil]];
    [self addPageObject:[CLPageObject objectForName:@"/UL" result:CL_POP
					objectClass:nil]];
    [self addPageObject:[CLPageObject objectForName:@"OL" result:CL_PUSH
					objectClass:nil]];
    [self addPageObject:[CLPageObject objectForName:@"/OL" result:CL_POP
					objectClass:nil]];
    [self addPageObject:[CLPageObject objectForName:@"LI" result:CL_PUSHDIFF
					objectClass:nil]];
    [self addPageObject:[CLPageObject objectForName:@"/LI" result:CL_POP
					objectClass:nil]];

    /* ClearLake tags */
    [self addPageObject:[CLPageObject objectForName:@"CL_MARKER" result:CL_APPEND
					objectClass:CLBlockClass]];
    [self addPageObject:[CLPageObject objectForName:@"CL_RANGEVIEW" result:CL_APPEND
					objectClass:CLRangeViewClass]];
    [self addPageObject:[CLPageObject objectForName:@"CL_SPLITTER" result:CL_APPEND
					objectClass:CLSplitterClass]];
    [self addPageObject:[CLPageObject objectForName:@"CL_PAGER" result:CL_PUSH
					objectClass:CLPagerClass]];
    [self addPageObject:[CLPageObject objectForName:@"/CL_PAGER" result:CL_POP
					objectClass:nil]];

    [self addPageObject:[CLPageObject objectForName:@"CL_BLOCK" result:CL_PUSH
					objectClass:nil]];
    [self addPageObject:[CLPageObject objectForName:@"/CL_BLOCK" result:CL_POP
					objectClass:nil]];
    
    [self addPageObject:[CLPageObject objectForName:@"CL_CHAINEDSELECT" result:CL_APPEND
					objectClass:CLChainedSelectClass]];

    /* Legacy - we never use this anymore */
    [self addPageObject:[CLPageObject objectForName:@"CL_CONTROL" result:CL_PUSH
					objectClass:CLControlClass]];
    [self addPageObject:[CLPageObject objectForName:@"/CL_CONTROL" result:CL_POP
					objectClass:nil]];
  }

  return CLPageObjects;
}

-(id) init
{
  return [self initFromTitle:nil];
}

-(id) initFromTitle:(CLString *) aTitle
{
  [super init];

  body = [[CLMutableArray alloc] init];
  header = [[CLMutableArray alloc] init];
  preHeader = [[CLMutableArray alloc] init];
  fileStack = nil;
  bodyAttributes = nil;
  title = [[CLBlock alloc] init];
  [title setPage:self];
  [title setContent:aTitle];
  usedFiles = nil;
  filename = nil;
  status = 200;
  frames = NO;

  owner = datasource = nil;
  messages = nil;
  
  return self;
}

-(void) pushString:(CLString *) aString withPath:(CLString *) aPath
{
  CLPageStack *aBuffer;


  aBuffer = [[CLPageStack alloc] initFromString:aString path:aPath];
  [fileStack addObject:aBuffer];
  [aBuffer release];

  if (aPath) {
    if (!usedFiles)
      usedFiles = [[CLMutableArray alloc] init];
    [usedFiles addObject:aPath];
  }

  return;
}

-(void) popFile
{
  [fileStack removeLastObject];  
  return;
}

-(void) includeFile:(CLString *) aPath
{
  CLPageStack *aBuffer;
  CLString *prefix = nil;
  CLString *aString;
      

  aBuffer = [fileStack lastObject];
  if (![aPath isAbsolutePath]) {
    if ([aBuffer path])
      prefix = [[aBuffer path] stringByDeletingLastPathComponent];
    else
      prefix = CLAppPath;
  }
  aPath = [CLPage findFile:aPath directory:prefix];

  if ((aString = [[CLString alloc] initWithContentsOfFile:aPath
				   encoding:CLUTF8StringEncoding])) {
    [self pushString:aString withPath:aPath];
    [aString release];
  }
      
  return;
}

#if 0
-(id) loadInline:(CLString *) aProgram asCGI:(BOOL) flag
{
  id anObject = nil;
  char *buf = NULL, *buf2 = NULL;
  size_t buflen = 0;
  FILE *file;


  file = popen([aProgram UTF8String], "r");

  if (flag)
    while (flgets(&buf, &buflen, file))
      if (buf[0] == '\n')
	break;
  
  while (flgets(&buf, &buflen, file))
    strlcat(&buf2, buf);

  pclose(file);

  anObject = [[CLBlock alloc] initFromString:buf2];
  if (buf)
    free(buf);
  if (buf2)
    free(buf2);
  
  return [anObject autorelease];
}
#endif

-(BOOL) hasCLAttributes:(CLElement *) aTag
{
  int i, j;
  CLArray *keys;
  id aKey;


  keys = [[aTag attributes] allKeys];
  for (i = 0, j = [keys count]; i < j; i++) {
    aKey = [keys objectAtIndex:i];
    if ([aKey length] >= 3 && ![aKey compare:@"CL_" options:CLCaseInsensitiveSearch
	       range:CLMakeRange(0, 3)])
      return YES;
  }

  return NO;
}

-(id) objectForTag:(CLElement *) aTag result:(CLResult *) aResult
	     stack:(CLMutableArray *) objStack
{
  CLString *aString;
  int result = CL_NOOBJECT;
  id anObject = nil;
  CLPageObject *pageObject;
  Class aClass;
  CLHashTable *poTable;
  
  
  aString = [aTag title];
  if (![aString caseInsensitiveCompare:@"BODY"]) {
    /* FIXME - eat all whitespace after this tag */
    bodyAttributes = [[aTag attributes] copy];
    result = CL_DISCARD;
  }
  else if (![aString caseInsensitiveCompare:@"/BODY"])
    result = CL_DISCARD;
  else if (![aString caseInsensitiveCompare:@"CL_PAGE"]) {
    /* FIXME - these should be checking for the = at the beginning of
       the string instead of just skipping it. */
    if (!owner && (aString = [[aTag attributes] objectForCaseInsensitiveString:@"CL_OWNER"]))
      owner = [[self datasourceForBinding:[aString substringFromIndex:1]] retain];
    if ((aString = [[aTag attributes] objectForCaseInsensitiveString:@"CL_DATASOURCE"]))
      datasource = [self datasourceForBinding:[aString substringFromIndex:1]];
    result = CL_DISCARD;
  }
  else {
    if (![aString caseInsensitiveCompare:@"FRAMESET"])
      frames = YES;
    
    poTable = [[self class] objectsForTags];
    if ((pageObject = CLHashTableDataForKey(poTable, aString, [aString hash],
					    @selector(isEqualToCaseInsensitiveString:)))) {
      result = [pageObject result];
      if ((aClass = [pageObject objectClass]))
	anObject = [[[aClass alloc] initFromElement:aTag onPage:self] autorelease];
      else if (result == CL_PUSH || result == CL_PUSHDIFF)
	anObject = [[[CLBlock alloc] initFromElement:aTag onPage:self] autorelease];
    }
  }

  *aResult = result;
  return anObject;
}

-(void) removeWhitespace:(CLMutableArray *) mArray index:(int) index all:(BOOL) flag
{
  id anObject;
  CLRange aRange, aRange2;
  CLCharacterSet *wSet;


  wSet = [CLCharacterSet whitespaceAndNewlineCharacterSet];
  
  do {
    anObject = [mArray objectAtIndex:index];
    if (![anObject isKindOfClass:CLStringClass])
      return;
    aRange = [anObject rangeOfCharacterNotFromSet:wSet options:0
					    range:CLMakeRange(0, [anObject length])];
    if (!flag) {
      aRange2 = [anObject rangeOfString:@"\n"];
      if (aRange2.length &&
	  ((aRange.length && CLMaxRange(aRange2) < aRange.location) ||
	   !aRange.length)) {
	aRange = aRange2;
	aRange.location++;
      }
    }
    if (!aRange.length)
      [mArray removeObjectAtIndex:index];
  } while (index < [mArray count] && !aRange.length);

  if (index < [mArray count]) {
    anObject = [anObject substringFromIndex:aRange.location];
    [mArray removeObjectAtIndex:index];
    [mArray insertObject:anObject atIndex:index];
  }

  return;
}

-(id) initFromFile:(CLString *) aFilename owner:anOwner
{
  CLString *aString;
  id anObject;

  
  if (!(aFilename = [CLPage findFile:aFilename directory:nil]) ||
      !(aString = [[CLString alloc] initWithContentsOfFile:aFilename
				    encoding:CLUTF8StringEncoding])) {
    [self initFromTitle:nil];
    [self release];
    return nil;
  }

  anObject = [self initFromString:aString owner:anOwner filename:aFilename];
  [aString release];
  return anObject;
}

-(id) initFromString:(CLString *) htmlString owner:anOwner
{
  return [self initFromString:htmlString owner:anOwner filename:nil];
}

-(void) closeObject:(CLElement *) closeTag in:(id) lastObject
{
  CLString *aTitle;
  CLMutableArray *mArray = nil;
  int i, j, k;
  id anObject;
  CLBlock *newBlock;
  CLRange aRange;


  aTitle = [[closeTag title] substringFromIndex:1];
  if ([lastObject isKindOfClass:CLPageClass])
    mArray = (CLMutableArray *) [lastObject body];
  else if ([lastObject isKindOfClass:CLSelectClass])
    mArray = [lastObject value];
  else if ([lastObject isKindOfClass:CLElementClass])
    mArray = [lastObject content];
  else if ([lastObject isKindOfClass:CLArrayClass])
    mArray = lastObject;
  
  for (i = [mArray count] - 1; i >= 0; i--) {
    anObject = [mArray objectAtIndex:i];
    if ([anObject isMemberOfClass:CLElementClass] &&
	![[((CLElement *) anObject) title] caseInsensitiveCompare:aTitle])
      break;
  }

  if (i < 0)
    [lastObject addObject:closeTag];
  else {
    aRange.location = i;
    if ([anObject isKindOfClass:CLBlockClass])
      newBlock = [anObject retain];
    else
      newBlock = [[CLBlock alloc] initFromElement:anObject onPage:self];
    for (k = i+1, j = [mArray count]; k < j; k++)
      [newBlock addObject:[mArray objectAtIndex:k]];
    aRange.length = j - aRange.location;
    [mArray removeObjectsInRange:aRange];
    [lastObject addObject:newBlock];
    [newBlock release];    
  }

  return;
}

-(id) initFromString:(CLString *) htmlString owner:anOwner filename:(CLString *) aFilename
{
  unichar c;
  int l1 = 0, l2 = 0;
  int p1 = 0, p2 = 0;
  unichar *b1 = NULL, *b2 = NULL;
  int inString, inElement, inComment, commentCount, inScript, allowComment;
  CLMutableArray *objStack;
  CLMutableArray *mArray;
  id anObject;
  CLString *aString;
  CLAutoreleasePool *pool;
  unichar *scriptBuf;
  CLString *scriptEnd = @"</SCRIPT";
  

  pool = [[CLAutoreleasePool alloc] init];
  
  [self initFromTitle:nil];
  filename = [aFilename copy];
  
  owner = [anOwner retain];
  
  if (!(b1 = malloc((l1 = BUFSIZE) * sizeof(unichar))))
    [self error:@"Unable to allocate memory"];
  if (!(b2 = malloc((l2 = BUFSIZE) * sizeof(unichar))))
    [self error:@"Unable to allocate memory"];

  fileStack = [[CLMutableArray alloc] init];
  [self pushString:htmlString withPath:filename];
  
  if (!(scriptBuf = malloc([scriptEnd length] * sizeof(unichar))))
    [self error:@"Unable to allocate memory"];
  [scriptEnd getCharacters:scriptBuf];

  mArray = [[CLMutableArray alloc] init];
  while ([fileStack count]) {
    while ((c = [[fileStack lastObject] nextCharacter])) {
      if (c == '<') {
	inString = inElement = inComment = commentCount = allowComment = 0;
	anObject = [mArray lastObject];
	inScript = [anObject isKindOfClass:CLElementClass] &&
	  ![[(CLElement *) anObject title] caseInsensitiveCompare:@"SCRIPT"];
	do {
	  b1[p1++] = c;

	  if (inScript && p1 <= [scriptEnd length] &&
	      towupper(b1[p1-1]) != scriptBuf[p1-1]) {
	    c = 0;
	    break;
	  }
	  
	  if (c == '!' && p1 == 2)
	    allowComment++;
	  if (allowComment) {
	    if (c == '-')
	      commentCount++;
	    else
	      commentCount = 0;
	    if (commentCount && !(commentCount % 2))
	      inComment = !inComment;
	  }
	  else if (!inComment && (c == '"' || c == '\'')) {
	    if (!inString)
	      inString = c;
	    else if (inString == c)
	      inString = 0;
	  }
	  else if (!inComment && !inString && c == '<')
	    inElement++;
	  else if (!inComment && !inString && c == '>')
	    inElement--;
	  if (p1 >= l1)
	    b1 = realloc(b1, (l1 += BUFSIZE) * sizeof(unichar));
	} while ((c = [[fileStack lastObject] nextCharacter]) &&
		 (c != '>' || inComment || inString || inElement > 1));
	
	if (c) {
	  b1[p1++] = c;
	  if (p1 >= l1)
	    b1 = realloc(b1, (l1 += BUFSIZE) * sizeof(unichar));
	}

	if (inScript && p1 <= [scriptEnd length]) {
	  if (p2 + p1 >= l2) {
	    while (p2 + p1 >= l2)
	      l2 += BUFSIZE;
	    b2 = realloc(b2, l2 * sizeof(unichar));
	  }
	  memcpy(&b2[p2], b1, p1 * sizeof(unichar));
	  p2 += p1;
	}
	else {
	  CLElement *aTag;

	  
	  if (p2) {
	    [mArray addObject:[CLString stringWithCharacters:b2 length:p2]];
	    p2 = 0;
	  }

	  aTag = [[CLElement alloc]
		   initFromString:[CLString stringWithCharacters:b1 length:p1]
		   onPage:self];

	  aString = [aTag title];
	  if (![aString compare:@"!--#include"]) { /* NOT case insensitive on purpose */
	    if ([[aTag attributes] objectForKey:@"virtual"])
	      [self includeFile:[[aTag attributes] objectForKey:@"virtual"]];
	    else if ([[aTag attributes] objectForKey:@"file"])
	      [self includeFile:[[aTag attributes] objectForKey:@"file"]];
	  }
	  else if ([aString length] && [aString characterAtIndex:0] == '!') {
	    [aTag release];
	    aTag = [[CLElement alloc] init];
	    [aTag setTitle:[CLString stringWithCharacters:b1+1 length:p1-2]];
	    [mArray addObject:aTag];
	  }
	  else 
	    [mArray addObject:aTag];
	  [aTag release];	
	}

	p1 = 0;
      }
      else {
	b2[p2++] = c;
	if (p2 >= l2)
	  b2 = realloc(b2, (l2 += BUFSIZE) * sizeof(unichar));
      }
    }

    [self popFile];
  }

  [fileStack release];
  fileStack = nil;
  
  if (p2) {
    [mArray addObject:[CLString stringWithCharacters:b2 length:p2]];
    p2 = 0;
  }

  if (b1)
    free(b1);
  if (b2)
    free(b2);

  objStack = [[CLMutableArray alloc] init];
  [objStack addObject:self];

  {
    int i, j;


    for (i = 0, j = [mArray count]; i < j; i++) {
      anObject = [mArray objectAtIndex:i];
      if ([anObject isKindOfClass:CLStringClass])
	[[objStack lastObject] addObject:anObject];
      else if ([anObject isKindOfClass:CLElementClass]) {
	aString = [(CLElement *) anObject title];

	if (![aString caseInsensitiveCompare:@"HTML"]) {
	  if ([body count]) {
	    [preHeader addObjectsFromArray:body];
	    [body removeAllObjects];
	  }
	  [self removeWhitespace:mArray index:i+1 all:YES];
	  j = [mArray count];
	}
	else if (![aString caseInsensitiveCompare:@"/HTML"])
	  /* Do Nothing */;
	else if (![aString caseInsensitiveCompare:@"HEAD"]) {
	  if ([body count]) {
	    if (![preHeader count])
	      [preHeader addObjectsFromArray:body];
	    else
	      [header addObjectsFromArray:body];
	    [body removeAllObjects];
	  }
	  [objStack addObject:header];
	  [self removeWhitespace:mArray index:i+1 all:NO];
	  j = [mArray count];
	}
	else if (![aString caseInsensitiveCompare:@"/HEAD"]) {
	  if ([objStack lastObject] == header)
	    [objStack removeLastObject];
	}
	else if (![aString caseInsensitiveCompare:@"TITLE"]) {
	  anObject = [[[CLBlock alloc] initFromElement:anObject onPage:self] autorelease];
	  [objStack addObject:anObject];
	}
	else if (![aString caseInsensitiveCompare:@"/TITLE"]) {
	  title = [[objStack lastObject] retain];
	  [objStack removeLastObject];
	}
	else {
	  CLResult result;
	  id newObject;


	  /* What? Close the head? We're awesome web designers, don't need to do that! */
	  if (![aString caseInsensitiveCompare:@"BODY"] && [objStack lastObject] == header)
	    [objStack removeLastObject];
	  
	  newObject = [self objectForTag:anObject result:&result stack:objStack];
	  
	  if (newObject)
	    anObject = newObject;
	  
	  switch (result) {
	  case CL_PUSHDIFF:
	    if ([[objStack lastObject] isKindOfClass:CLBlockClass] &&
		![[((CLElement *) [objStack lastObject]) title]
		   caseInsensitiveCompare:[((CLElement *) anObject) title]])
	      [objStack removeLastObject];
	    /* Fall-through intentional */
	  case CL_PUSH:
	    [[objStack lastObject] addObject:anObject];
	    [objStack addObject:anObject];
	    break;
	  case CL_POP:
	    /* Compensate for mismatched tags */
	    while ([[objStack lastObject] isKindOfClass:CLBlockClass] &&
		   [[((CLElement *) [objStack lastObject]) title]
					 caseInsensitiveCompare:
		       [[((CLElement *) anObject) title]
					      substringFromIndex:1]])
	      [objStack removeLastObject];
	    [objStack removeLastObject];
	    break;
	  case CL_DISCARD:
	    [self removeWhitespace:mArray index:i+1 all:NO];
	    j = [mArray count];
	    break;
	  case CL_APPEND:
	  default:
	    aString = [(CLElement *) anObject title];
	    if ([aString length] && [aString characterAtIndex:0] == '/')
	      [self closeObject:anObject in:[objStack lastObject]];
	    else {
	      /* FIXME - close objects that can't nest like P and LI
		 and OPTION and TR/TD/TH */
	      [[objStack lastObject] addObject:anObject];
	    }
	    break;
	  }
	}
      }
      else
	[self error:@"WTF is this?"];
    }
  }

  [mArray release];
  
  if ([[CLQuery objectForKey:QUERY_DEBUG] boolValue]) {
    const char *p;


    aString = nil;
    if ((p = getenv("HTTP_USER_AGENT")))
      aString = [CLString stringWithUTF8String:p];
    if (![aString hasPrefix:@"Mozilla/4.0 (compatible; MSIE 6.0"] && [usedFiles count]) {
      int i, j;


      [self addObject:@"<!-- FILES:"];
      for (i = 0, j = [usedFiles count]; i < j; i++) {
	if (i)
	  [self addObject:@", "];
	[self addObject:[[usedFiles objectAtIndex:i] lastPathComponent]];
      }
      [self addObject:@" -->"];
    }
  }

  [objStack release];
  free(scriptBuf);
  [pool release];

  return self;
}

-(void) dealloc
{
  [owner release];

  [body release];
  [header release];
  [preHeader release];
  [bodyAttributes release];
  [fileStack release];
  [usedFiles release];
  [filename release];
  [messages release];

  [super dealloc];
  return;
}

#if DEBUG_RETAIN
#undef copy
-(id) copy:(const char *) file :(int) line :(id) retainer
#else
-(id) copy
#endif
{
  CLPage *aCopy;


#if DEBUG_RETAIN
  aCopy = [super copy:file :line :retainer];
#define copy		copy:__FILE__ :__LINE__ :self
#else
  aCopy = [super copy];
#endif
  aCopy->body = [body copy];
  aCopy->header = [header copy];
  aCopy->preHeader = [preHeader copy];
  aCopy->bodyAttributes = [bodyAttributes copy];
  aCopy->title = [title copy];
  aCopy->fileStack = nil;
  aCopy->usedFiles = [usedFiles copy];
  aCopy->owner = [owner retain];
  aCopy->datasource = datasource;
  return aCopy;
}

-(void) addObject:(id) anObject
{
  [body addObject:anObject];
  if ([anObject respondsTo:@selector(setPage:)])
    [anObject setPage:self];
  return;
}

-(void) addObjectToHeader:(id) anObject
{
  [header addObject:anObject];
  if ([anObject respondsTo:@selector(setPage:)])
    [anObject setPage:self];
  return;
}

-(CLArray *) body
{
  return body;
}

-(CLArray *) header
{
  return header;
}

-(CLArray *) preHeader
{
  return preHeader;
}

-(id) owner
{
  return owner;
}

-(id) datasource
{
  if (!datasource)
    return owner;
  return datasource;
}

-(id) datasourceForBinding:(CLString *) aBinding
{
  CLRange aRange;
  CLString *aString;
  id anObject = nil;
  BOOL found;


  aRange = [aBinding rangeOfString:@"." options:0 range:CLMakeRange(0, [aBinding length])];
  if (!aRange.length)
    aString = aBinding;
  else
    aString = [aBinding substringToIndex:aRange.location];

  if ([aString isEqualToString:@"@"])
    anObject = self;
  else if ([aString hasPrefix:@"#"])
    anObject = [self objectWithID:[aString substringFromIndex:1]];
  else if (iswupper([aString characterAtIndex:0])) {
    if (!(anObject = [[[objc_lookUpClass([aString UTF8String]) alloc] init] autorelease])) {
#if 0
      /* See if there's any database tables that might match */
      if ((anObject = [CLDefaultContext tableForClassName:aString]))
	anObject = [CLDefaultContext classForTable:anObject];
#endif
    }
  }
  else
    anObject = [[self datasource] objectValueForBinding:aString found:&found];
    
  if (aRange.length)
    anObject = [anObject objectValueForBinding:
			   [aBinding substringFromIndex:CLMaxRange(aRange)] found:&found];
  
  return anObject;
}

-(void) updateBindings:(CLArray *) anArray
{
  int i, j;
  id anObject;


  for (i = 0, j = [anArray count]; i < j; i++) {
    anObject = [anArray objectAtIndex:i];
    if ([anObject respondsTo:@selector(updateBinding)])
      [anObject updateBinding];
  }

  return;
}

-(void) updateBindings
{
  [self updateBindings:preHeader];
  [self updateBindings:header];
  [self updateBindings:body];
  [title updateBinding];
  return;
}

-(id) objectValueForBinding:(CLString *) aBinding found:(BOOL *) found
{
  CLRange aRange;
  CLString *aString;
  id anObject = nil;


  *found = NO;
  
  aRange = [aBinding rangeOfString:@"." options:0 range:CLMakeRange(0, [aBinding length])];
  if (!aRange.length)
    aString = aBinding;
  else
    aString = [aBinding substringToIndex:aRange.location];

  if (!(anObject = [self objectWithID:aString]))
    return [super objectValueForBinding:aBinding found:found];

  *found = YES;
  
  if (aRange.length)
    anObject = [anObject objectValueForBinding:
			   [aBinding substringFromIndex:CLMaxRange(aRange)] found:found];
  
  return anObject;
}

-(CLString *) filename
{
  return filename;
}

-(CLUInteger) status
{
  return status;
}

-(CLString *) statusString
{
  int i;


  for (i = 0; CLStatusStrings[i].status && status >= CLStatusStrings[i].status; i++)
    if (CLStatusStrings[i].status == status)
      return CLStatusStrings[i].string;

  return nil;
}

-(void) setStatus:(CLUInteger) aValue
{
  status = aValue;
  return;
}

-(CLBlock *) title
{
  return title;
}

-(void) setTitle:(CLString *) aTitle
{
  if (!title) {
    title = [[CLBlock alloc] init];
    [title setPage:self];
  }
  [title setContent:aTitle];
  return;
}
       
-(void) writeHTML:(CLStream *) stream
{
  [self writeHTML:stream withHeaders:YES];
  return;
}

-(BOOL) needsLoadEvent:(CLArray *) anArray
{
  int i, j;
  id anObject;


  for (i = 0, j = [anArray count]; i < j; i++) {
    anObject = [anArray objectAtIndex:i];
    if ([anObject isKindOfClass:CLChainedSelectClass])
      return YES;

    if ([anObject respondsTo:@selector(content)] &&
	[[anObject content] isKindOfClass:CLArrayClass] &&
	[self needsLoadEvent:[anObject content]])
      return YES;
  }
  
  return NO;
}

-(void) writeHTML:(CLStream *) stream withHeaders:(BOOL) showHeaders
{
  [self writeHTML:stream withHeaders:showHeaders output:NULL];
  return;
}

-(void) writeHTML:(CLStream *) stream withHeaders:(BOOL) showHeaders
	   output:(CLData **) output
{
  int j, k;
  CLStream *stream2;
  CLData *aData;
  int gz = NO;


  stream2 = [CLStream openMemoryForWriting];
  CLWriteHTMLObject(stream2, preHeader);

  CLPrintf(stream2, @"<HTML>\n");

  CLPrintf(stream2, @"<HEAD>\n");
  if (title) {
    CLPrintf(stream2, @"<TITLE>");
    CLWriteHTMLObject(stream2, [title content]);
    CLPrintf(stream2, @"</TITLE>\n");
  }

  {
    CLString *aString;
    CLString *documentRoot;
    unistr baseURL, baseDir;


    /* Lame, lame, lame. I have to write out a full URL into the BASE
       tag, not a relative one. */

    documentRoot = [CLEnvironment objectForKey:@"DOCUMENT_ROOT"];
    
    if ([filename hasPathPrefix:documentRoot]) {
      baseDir = CLCopyStackString(@"/", [filename length]);
      [((CLMutableString *) &baseDir) appendPathComponent:filename];
      [((CLMutableString *) &baseDir) deleteLastPathComponent];
      [((CLMutableString *) &baseDir) deletePathPrefix:documentRoot];
      if ([CLDelegate respondsTo:@selector(page:willUseBaseDirectory:)] &&
	  (aString = [CLDelegate page:self willUseBaseDirectory:(CLString *) &baseDir])) {
	baseDir = CLCloneStackString(aString);
      }
      baseURL = CLCopyStackString(CLServerURL, baseDir.len + 2);
      if (baseDir.len)
	[((CLMutableString *) &baseURL) appendPathComponent:(CLString *) &baseDir];
    }
    else {
      baseURL = CLCopyStackString(CLServerURL, [CLWebPath length] + 2);
      [((CLMutableString *) &baseURL) appendString:CLWebPath];
    }
    [((CLMutableString *) &baseURL) appendPathComponent:@"/"];
    [stream2 writeFormat:@"<BASE HREF=\"%@\">\n" usingEncoding:CLUTF8StringEncoding,
	     (CLString *) &baseURL];
  }

  CLWriteHTMLObject(stream2, header);

  if ([self needsLoadEvent:body])
    CLPrintf(stream2, @""
	     "<SCRIPT LANGUAGE=JavaScript>\n"
	     "function CLAddLoadEvent(func) {\n"
	     "  var oldonload = window.onload;\n"
	     "  if (typeof window.onload != 'function')\n"
	     "    window.onload = func;\n"
	     "  else\n"
	     "    window.onload = function() {\n"
	     "      oldonload();\n"
	     "      func();\n"
	     "    }\n"
	     "}\n"
	     "</SCRIPT>\n");

  CLPrintf(stream2, @"</HEAD>\n");

  if (!frames) {
    CLPrintf(stream2, @"<BODY");
    [CLElement writeAttributes:bodyAttributes using:self to:stream2];
    CLPrintf(stream2, @">\n");
  }

  CLWriteHTMLObject(stream2, body);

  if (!frames)
    CLPrintf(stream2, @"</BODY>\n");
  CLPrintf(stream2, @"</HTML>\n");

  /* Gotta write the headers to do gzip. Without the headers, we won't
     know anymore that it has been gzipped! */
  gz = showHeaders && CLBrowserAcceptsGzip();

  aData = [stream2 data];
  if (output)
    *output = aData;

  if (showHeaders) {
    CLPrintf(stream, @"Status: %u %@\r\n", status, [self statusString]);
    CLPrintf(stream, @"Content-Type: text/html; charset=UTF-8\r\n");
    CLPrintf(stream, @"Content-Length: %u\r\n", [aData length]);
    CLPrintf(stream, @"Cache-Control: must-revalidate\r\n");
  }
  
  if (gz) {
    CLData *gzData;


    if (!CLDeflate([aData bytes], [aData length], 9, &gzData)) {
      if (showHeaders)
	CLPrintf(stream, @"Content-Encoding: gzip\r\n");
      aData = gzData;
    }
    else
      gz = 0;
  }

  if (showHeaders) {
    CLPrintf(stream, @"Content-Length: %i\r\n", [aData length]);
    //CLPrintf(stream, @"Cache-Control: no-store\r\n");
    //CLPrintf(stream, @"Expires: -1\r\n");
    for (j = 0, k = [CLCookies count]; j < k; j++)
      if (![[CLCookies objectAtIndex:j] isFromBrowser])
	CLPrintf(stream, @"Set-Cookie: %@\r\n",
		 [[CLCookies objectAtIndex:j] cookieString]);
    CLPrintf(stream, @"\r\n");
  }
    
  [stream writeData:aData];
  [stream2 close];
  return;
}

-(CLArray *) allIDs:(CLArray *) anArray
{
  int i, j;
  CLMutableArray *mArray;
  id anObject;
  CLString *aString;


  mArray = [[CLMutableArray alloc] init];
  
  for (i = 0, j = [anArray count]; i < j; i++) {
    anObject = [anArray objectAtIndex:i];
    if ([anObject respondsTo:@selector(attributes)] &&
	(aString = [[anObject attributes] objectForCaseInsensitiveString:@"ID"]))
      [mArray addObject:aString];

    if ([anObject respondsTo:@selector(content)] &&
	[[anObject content] isKindOfClass:CLArrayClass] &&
	(anObject = [self allIDs:[anObject content]]))
      [mArray addObjectsFromArray:anObject];
  }

  if (![mArray count]) {
    [mArray release];
    mArray = nil;
  }
  
  return [mArray autorelease];
}

-(CLArray *) findDuplicates:(CLArray *) anArray
{
  int i, j;
  CLMutableArray *mArray;
  CLString *aString;


  mArray = [[CLMutableArray alloc] init];
  for (i = [anArray count] - 1; i >= 0; i--) {
    aString = [anArray objectAtIndex:i];
    j = [anArray indexOfObject:aString];
    if (i != j && ![mArray containsObject:aString])
      [mArray addObject:aString];
  }

  if (![mArray count]) {
    [mArray release];
    mArray = nil;
  }
  
  return [mArray autorelease];
}

-(void) display
{
  [self display:NULL];
  return;
}

-(void) display:(CLData **) output
{
  CLStream *stream;
  const void *data;
  int i;
  BOOL disp;
  

  if (output)
    *output = nil;
  
  CLMainPage = self;

  if (!(disp = [[CLManager manager] checkPermission:self]) &&
      [CLDelegate respondsTo:@selector(accessDenied:)])
    [CLDelegate accessDenied:self];

  if (disp && [owner respondsTo:@selector(pageShouldDisplay:)])
    disp = [owner pageShouldDisplay:self];
  if (disp && [CLDelegate respondsTo:@selector(pageShouldDisplay:)])
    disp = [CLDelegate pageShouldDisplay:self];

  if (disp) {
    if ([owner respondsTo:@selector(pageWillDisplay:)])
      [owner pageWillDisplay:self];
    if (owner != CLDelegate && [CLDelegate respondsTo:@selector(pageWillDisplay:)])
      [CLDelegate pageWillDisplay:self];
    
    [self updateBindings];

#if 0
    if ([CLAppName hasSuffix:@"-staging"]) {
      CLArray *anArray;
      CLMutableString *mString;


      anArray = [self allIDs:body];
      anArray = [self findDuplicates:anArray];
      if ([anArray count]) {
	mString = [CLMutableString stringWithString:@"Duplicate IDs: "];
	for (i = 0, j = [anArray count]; i < j; i++) {
	  if (i)
	    [mString appendString:@", "];
	  [mString appendString:[anArray objectAtIndex:i]];
	}
	[body insertObject:mString atIndex:0];
      }
    }  
#endif

    stream = [CLStream openMemoryForWriting];
    [self writeHTML:stream withHeaders:YES output:output];
    data = [stream bytes];
    i = [stream length];
    fwrite(data, 1, i, stdout);
    [stream close];
    fflush(stdout);
  }

#if 0
  {
    extern int mysqlCount;
    fprintf(stderr, "Count: %i\n", mysqlCount);
  }
#endif
  
  return;
}

-(CLData *) htmlForBody
{
  CLStream *stream;


  stream = [CLStream openMemoryForWriting];
  CLWriteHTMLObject(stream, body);
  [stream close];
  return [stream data];
}  

-(CLDictionary *) bodyAttributes
{
  return bodyAttributes;
}

-(CLArray *) usedFiles
{
  return usedFiles;
}

-(void) appendString:(CLString *) aString
{
  [body addObject:aString];
  return;
}

-(void) appendStringToHeader:(CLString *) aString
{
  [header addObject:aString];
  return;
}

-(id) objectWithID:(CLString *) idString fromArray:(CLArray *) anArray
{
  int i, j;
  id anObject;
  CLString *aString;
  BOOL success;


  for (i = 0, j = [anArray count]; i < j; i++) {
    anObject = [anArray objectAtIndex:i];
    if ([anObject respondsTo:@selector(attributes)]) {
      if ([[[anObject attributes] objectForCaseInsensitiveString:@"ID"]
	    isEqualToString:idString])
	return anObject;
      if ((aString = [[anObject attributes] objectForCaseInsensitiveString:@"CL_ID"])) {
	aString = [[anObject expandBinding:aString success:&success] description];
	if ([aString isEqualToString:idString])
	  return anObject;
      }
    }

    if ([anObject respondsTo:@selector(content)] &&
	[[anObject content] isKindOfClass:CLArrayClass] &&
	(anObject = [self objectWithID:idString fromArray:[anObject content]]))
      return anObject;
  }
  
  return nil;
}

-(id) objectWithID:(CLString *) aString
{
  id anObject;
 
  
  if (!(anObject = [self objectWithID:aString fromArray:body]))
    if (!(anObject = [self objectWithID:aString fromArray:header]))
      anObject = [self objectWithID:aString fromArray:preHeader];
  
  return anObject;
}

-(void) addInfoMessage:(CLInfoMessage *) aMessage
{
  if (!messages)
    messages = [[CLMutableArray alloc] init];
  [messages addObject:aMessage];
  return;
}

-(void) removeInfoMessage:(CLInfoMessage *) aMessage
{
  [messages removeObject:aMessage];
  return;
}

-(CLArray *) messages
{
  return messages;
}

@end

void CLRedirectBrowser(CLString *newURL, BOOL includeQuery, int status)
{
  int i, j, c;
  CLRange aRange;
  CLString *aKey, *statusString;
  CLArray *keys;
  CLMutableString *mString;
  id aValue;


  aRange = [newURL rangeOfString:@"?"];
  if (!aRange.length && [CLQuery count] && includeQuery) {
    mString = [newURL mutableCopy];
    keys = [CLQuery allKeys];
    for (c = '?', i = 0, j = [keys count]; i < j; i++) {
      aKey = [keys objectAtIndex:i];
      if ([aKey hasPrefix:@"CLurl"])
	continue;
      
      aValue = [CLQuery objectForKey:aKey];
      if (aValue && aValue != CLNullObject)
	[mString appendFormat:@"%c%@=%@", c, [[aKey description]
					       stringByAddingPercentEscapes],
		 [[aValue description] stringByAddingPercentEscapes]];
      else
	[mString appendFormat:@"%c%@", c, [[aKey description] stringByAddingPercentEscapes]];

      c = '&';      
    }
#if DEBUG_RETAIN
    id self = nil;
#endif
    newURL = [mString autorelease];
  }

  statusString = nil;
  for (i = 0; CLStatusStrings[i].status && status >= CLStatusStrings[i].status; i++)
    if (CLStatusStrings[i].status == status)
      statusString = CLStatusStrings[i].string;

  printf("Status: %i", status);
  if (statusString)
    printf(" %s", [statusString UTF8String]);
  printf("\r\n");
  printf("Location: %s\r\n", [newURL UTF8String]);
  for (i = 0, j = [CLCookies count]; i < j; i++)
    if (![[CLCookies objectAtIndex:i] isFromBrowser])
      printf("Set-Cookie: %s\n",
	     [[[CLCookies objectAtIndex:i] cookieString] UTF8String]);
  printf("Content-Type: text/html\r\n");
  printf("\r\n");
  printf("<HTML><HEAD>"
	 "<TITLE>%i", status);
  if (statusString)
    printf(" %s", [statusString UTF8String]);
  printf("</TITLE>"
	 "</HEAD><BODY>"
	 "<H1>Moved Temporarily</H1>"
	 "The document has moved <A HREF=\"%s\">here</A>.<P>"
	 "</BODY></HTML>"
	 "\r\n", [newURL UTF8String]);

  exit(0);
  return;
}

void CLRedirectBrowserToPage(CLString *aFilename, BOOL includeQuery)
{
  CLControl *aControl;
  CLPageTarget *aTarget;
  CLString *aString;


#if DEBUG_RETAIN
    id self = nil;
#endif
  aControl = [[CLControl alloc] init];
  aTarget = [[CLPageTarget alloc] initFromPath:aFilename];
  [aControl setTarget:aTarget];
  [aControl setAction:@selector(showPage:)];
  aString = [aControl generateURL];
  [aControl release];
  [aTarget release];

  CLRedirectBrowser(aString, includeQuery, 303);
}
