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

#import "CLPage.h"
#import "CLPageStack.h"
#import "CLPageObject.h"
#import "CLOpenFile.h"
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
#import "CLField.h"
#import "CLScriptElement.h"
#import "CLAccount.h"
#import "CLManager.h"
#import "CLSession.h"
#import "CLRangeView.h"
#import "CLPager.h"
#import "CLNumber.h"
#import "CLChainedSelect.h"
#import "CLSplitter.h"
#import "CLCharacterSet.h"
#import "CLNull.h"
#import "CLPageTarget.h"
#import "CLData.h"
#import "CLCalendarDate.h"
#import "CLObjCAPI.h"

#include <stdlib.h>
#include <ctype.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <wctype.h>

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
  {416, @"Expectation Failed"},
  {500, @"Internal Server Error"},
  {501, @"Not Implemented"},
  {502, @"Bad Gateway"},
  {503, @"Service Unavailable"},
  {504, @"Gateway Timeout"},
  {505, @"HTTP Version Not Supported"},
  {0, nil}
};

CLMutableArray *CLPageObjects = nil;

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

+(CLPage *) pageFromFile:(CLString *) aFilename owner:(id) anOwner
{
  return [[[[self class] alloc] initFromFile:aFilename owner:anOwner] autorelease];
}

+(CLString *) findFile:(CLString *) aFilename directory:(CLString *) aDir
{
  CLMutableArray *dirs = nil;
  CLString *aString;

  
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
    CLPageExtensions = [[CLArray alloc]
			 initWithObjects:@"html", @"shtml", @"htm", nil];

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

+(CLMutableArray *) objectsForTags
{
  if (!CLPageObjects) {
    CLPageObjects = [[CLMutableArray alloc] init];

    [CLPageObjects addObject:[CLPageObject objectForName:@"IMG" result:CL_APPEND
						   objectClass:[CLImageElement class]]];
    [CLPageObjects addObject:[CLPageObject objectForName:@"FORM" result:CL_PUSH
						   objectClass:[CLForm class]]];
    [CLPageObjects addObject:[CLPageObject objectForName:@"/FORM" result:CL_POP
						   objectClass:nil]];
    [CLPageObjects addObject:[CLPageObject objectForName:@"A" result:CL_PUSH
						   objectClass:[CLControl class]]];
    [CLPageObjects addObject:[CLPageObject objectForName:@"/A" result:CL_POP
						   objectClass:nil]];
    [CLPageObjects addObject:[CLPageObject objectForName:@"SCRIPT" result:CL_PUSH
						   objectClass:[CLScriptElement class]]];
    [CLPageObjects addObject:[CLPageObject objectForName:@"/SCRIPT" result:CL_POP
						   objectClass:nil]];

    [CLPageObjects addObject:[CLPageObject objectForName:@"INPUT" result:CL_APPEND
						   objectClass:[CLField class]]];
    [CLPageObjects addObject:[CLPageObject objectForName:@"BUTTON" result:CL_PUSH
						   objectClass:[CLField class]]];
    [CLPageObjects addObject:[CLPageObject objectForName:@"/BUTTON" result:CL_POP
						   objectClass:nil]];
    [CLPageObjects addObject:[CLPageObject objectForName:@"TEXTAREA" result:CL_PUSH
						   objectClass:[CLField class]]];
    [CLPageObjects addObject:[CLPageObject objectForName:@"/TEXTAREA" result:CL_POP
						   objectClass:nil]];
    [CLPageObjects addObject:[CLPageObject objectForName:@"SELECT" result:CL_PUSH
						   objectClass:[CLField class]]];
    [CLPageObjects addObject:[CLPageObject objectForName:@"/SELECT" result:CL_POP
						   objectClass:nil]];

    /* FIXME - this one returns aTag instead of nil */
    [CLPageObjects addObject:[CLPageObject objectForName:@"OPTION" result:CL_APPEND
						   objectClass:nil]];
    [CLPageObjects addObject:[CLPageObject objectForName:@"/OPTION" result:CL_APPEND
						   objectClass:nil]];
    [CLPageObjects addObject:[CLPageObject objectForName:@"BASE" result:CL_APPEND
						   objectClass:nil]];
    
    [CLPageObjects addObject:[CLPageObject objectForName:@"LABEL" result:CL_PUSH
						   objectClass:nil]];
    [CLPageObjects addObject:[CLPageObject objectForName:@"/LABEL" result:CL_POP
						   objectClass:nil]];
    [CLPageObjects addObject:[CLPageObject objectForName:@"DIV" result:CL_PUSH
						   objectClass:nil]];
    [CLPageObjects addObject:[CLPageObject objectForName:@"/DIV" result:CL_POP
						   objectClass:nil]];
    [CLPageObjects addObject:[CLPageObject objectForName:@"SPAN" result:CL_PUSH
						   objectClass:nil]];
    [CLPageObjects addObject:[CLPageObject objectForName:@"/SPAN" result:CL_POP
						   objectClass:nil]];
    [CLPageObjects addObject:[CLPageObject objectForName:@"STYLE" result:CL_PUSH
						   objectClass:nil]];
    [CLPageObjects addObject:[CLPageObject objectForName:@"/STYLE" result:CL_POP
						   objectClass:nil]];
    [CLPageObjects addObject:[CLPageObject objectForName:@"TABLE" result:CL_PUSH
						   objectClass:nil]];
    [CLPageObjects addObject:[CLPageObject objectForName:@"/TABLE" result:CL_POP
						   objectClass:nil]];
    [CLPageObjects addObject:[CLPageObject objectForName:@"TR" result:CL_PUSH
						   objectClass:nil]];
    [CLPageObjects addObject:[CLPageObject objectForName:@"/TR" result:CL_POP
						   objectClass:nil]];
    [CLPageObjects addObject:[CLPageObject objectForName:@"TD" result:CL_PUSH
						   objectClass:nil]];
    [CLPageObjects addObject:[CLPageObject objectForName:@"/TD" result:CL_POP
						   objectClass:nil]];
    [CLPageObjects addObject:[CLPageObject objectForName:@"TH" result:CL_PUSH
						   objectClass:nil]];
    [CLPageObjects addObject:[CLPageObject objectForName:@"/TH" result:CL_POP
						   objectClass:nil]];
    [CLPageObjects addObject:[CLPageObject objectForName:@"UL" result:CL_PUSH
						   objectClass:nil]];
    [CLPageObjects addObject:[CLPageObject objectForName:@"/UL" result:CL_POP
						   objectClass:nil]];
    [CLPageObjects addObject:[CLPageObject objectForName:@"OL" result:CL_PUSH
						   objectClass:nil]];
    [CLPageObjects addObject:[CLPageObject objectForName:@"/OL" result:CL_POP
						   objectClass:nil]];

    [CLPageObjects addObject:[CLPageObject objectForName:@"LI" result:CL_PUSHDIFF
						   objectClass:nil]];
    [CLPageObjects addObject:[CLPageObject objectForName:@"/LI" result:CL_POP
						   objectClass:nil]];

    /* ClearLake tags */
    [CLPageObjects addObject:[CLPageObject objectForName:@"CL_MARKER" result:CL_APPEND
						   objectClass:[CLBlock class]]];
    [CLPageObjects addObject:[CLPageObject objectForName:@"CL_RANGEVIEW" result:CL_APPEND
						   objectClass:[CLRangeView class]]];
    [CLPageObjects addObject:[CLPageObject objectForName:@"CL_SPLITTER" result:CL_APPEND
						   objectClass:[CLSplitter class]]];
    [CLPageObjects addObject:[CLPageObject objectForName:@"CL_PAGER" result:CL_PUSH
						   objectClass:[CLPager class]]];
    [CLPageObjects addObject:[CLPageObject objectForName:@"/CL_PAGER" result:CL_POP
						   objectClass:nil]];

    [CLPageObjects addObject:[CLPageObject objectForName:@"CL_BLOCK" result:CL_PUSH
						   objectClass:nil]];
    [CLPageObjects addObject:[CLPageObject objectForName:@"/CL_BLOCK" result:CL_POP
						   objectClass:nil]];
    
    [CLPageObjects addObject:[CLPageObject objectForName:@"CL_CHAINEDSELECT" result:CL_APPEND
						   objectClass:[CLChainedSelect class]]];

    /* Legacy - we never use this anymore */
    [CLPageObjects addObject:[CLPageObject objectForName:@"CL_CONTROL" result:CL_PUSH
						   objectClass:[CLControl class]]];
    [CLPageObjects addObject:[CLPageObject objectForName:@"/CL_CONTROL" result:CL_POP
						   objectClass:nil]];
    
    /* FIXME - this one returns aTag instead of nil */
    [CLPageObjects addObject:[CLPageObject objectForName:@"/CL_VARNAME" result:CL_APPEND
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
  [title setValue:aTitle];
  usedFiles = nil;
  filename = nil;
  status = 200;
  frames = NO;

  cl_messageBlock = cl_errorText = cl_infoText = nil;
  
  owner = datasource = nil;
  
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
  CLArray *anArray;
  int i, j;
  CLPageObject *pageObject;
  Class aClass;
  
  
  aString = [aTag title];
  if (![aString caseInsensitiveCompare:@"BODY"]) {
    /* FIXME - eat all whitespace after this tag */
    bodyAttributes = [[aTag attributes] copy];
    result = CL_DISCARD;
  }
  else if (![aString caseInsensitiveCompare:@"/BODY"])
    result = CL_DISCARD;
  else if (![aString caseInsensitiveCompare:@"CL_PAGE"]) {
    if (!owner && (aString = [[aTag attributes] objectForCaseInsensitiveString:@"CL_OWNER"]))
      owner = [[self datasourceForBinding:aString] retain];
    if ((aString = [[aTag attributes] objectForCaseInsensitiveString:@"CL_DATASOURCE"]))
      datasource = [self datasourceForBinding:aString];
    result = CL_DISCARD;
  }
  else {
    if (![aString caseInsensitiveCompare:@"FRAMESET"])
      frames = YES;
    
    anArray = [[self class] objectsForTags];
    for (i = 0, j = [anArray count]; i < j; i++) {
      pageObject = [anArray objectAtIndex:i];
      if (![[pageObject name] caseInsensitiveCompare:aString]) {
	result = [pageObject result];
	if ((aClass = [pageObject objectClass]))
	  anObject = [[[aClass alloc] initFromElement:aTag onPage:self] autorelease];
	else if (result == CL_PUSH || result == CL_PUSHDIFF)
	  anObject = [[[CLBlock alloc] initFromElement:aTag onPage:self] autorelease];
	break;
      }
    }
  }

  *aResult = result;
  return anObject;
}

-(void) removeWhitespace:(CLMutableArray *) mArray index:(int) index all:(BOOL) flag
{
  id anObject;
  CLRange aRange, aRange2;
  CLCharacterSet *notWSet;


  notWSet = [[CLCharacterSet whitespaceAndNewlineCharacterSet] invertedSet];
  
  do {
    anObject = [mArray objectAtIndex:index];
    if (![anObject isKindOfClass:[CLString class]])
      return;
    aRange = [anObject rangeOfCharacterFromSet:notWSet];
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
  if ([lastObject isKindOfClass:[CLPage class]])
    mArray = (CLMutableArray *) [lastObject body];
  else if ([lastObject isKindOfClass:[CLElement class]])
    mArray = [lastObject value];
  else if ([lastObject isKindOfClass:[CLArray class]])
    mArray = lastObject;
  
  for (i = [mArray count] - 1; i >= 0; i--) {
    anObject = [mArray objectAtIndex:i];
    if ([anObject isMemberOfClass:[CLElement class]] &&
	![[((CLElement *) anObject) title] caseInsensitiveCompare:aTitle])
      break;
  }

  if (i < 0)
    [lastObject addObject:closeTag];
  else {
    aRange.location = i;
    if ([anObject isKindOfClass:[CLBlock class]])
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
	inScript = [anObject isKindOfClass:[CLElement class]] &&
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
      if ([anObject isKindOfClass:[CLString class]])
	[[objStack lastObject] addObject:anObject];
      else if ([anObject isKindOfClass:[CLElement class]]) {
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
	  
	  if (newObject && anOwner &&
	      (aString = [[newObject attributes]
			   objectForCaseInsensitiveString:@"CL_VARNAME"]))
	    CLObjectSetInstanceVariable(anOwner, [aString UTF8String], newObject);
	  if (newObject)
	    anObject = newObject;
	  
	  switch (result) {
	  case CL_PUSHDIFF:
	    if ([[objStack lastObject] isKindOfClass:[CLBlock class]] &&
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
	    while ([[objStack lastObject] isKindOfClass:[CLBlock class]] &&
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

  [self setInstanceVariable:@"cl_errorText"];
  [self setInstanceVariable:@"cl_infoText"];
  [self setInstanceVariable:@"cl_messageBlock"];
  [self setInstanceVariable:@"cl_logoutControl"];
  [self setInstanceVariable:@"cl_loginControl"];
  free(scriptBuf);
  [pool release];

  return self;
}

-(void) clearInstanceVariables:(CLArray *) anArray
{
  int i, j;
  id anObject;
  CLString *aString;


  for (i = 0, j = [anArray count]; i < j; i++) {
    anObject = [anArray objectAtIndex:i];
    if ([anObject respondsTo:@selector(attributes)] &&
	(aString = [[anObject attributes] objectForCaseInsensitiveString:@"CL_VARNAME"]))
      CLObjectSetInstanceVariable(owner, [aString UTF8String], nil);

    if ([anObject respondsTo:@selector(value)] &&
	[[anObject value] isKindOfClass:[CLArray class]])
      [self clearInstanceVariables:[anObject value]];
  }
  
  return;
}

-(void) dealloc
{
  CLAutoreleasePool *pool = [[CLAutoreleasePool alloc] init];

  
  if (owner) {
    [self clearInstanceVariables:preHeader];
    [self clearInstanceVariables:header];
    [self clearInstanceVariables:body];
  }
  [owner release];

  [body release];
  [header release];
  [preHeader release];
  [bodyAttributes release];
  [fileStack release];
  [usedFiles release];
  [filename release];
  [pool release];

  [super dealloc];
  return;
}

-(id) copy
{
  CLPage *aCopy;


  aCopy = [super copy];
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
      /* See if there's any database tables that might match */
      if ((anObject = [CLGenericRecord tableForClassName:aString]))
	anObject = [CLGenericRecord classForTable:anObject];
    }
  }
  else {
    /* FIXME - maybe if it's an ID it should be prefixed with # or something? */
    anObject = [[self datasource] objectValueForBinding:aString found:&found];
    if (!found)
      anObject = [self objectWithID:aString];
  }
    
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

  if (!(anObject = [self objectWithID:aString]) &&
      !(anObject = [self objectForVariable:aString]))
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
  [title setValue:aTitle];
  return;
}
       
-(void) writeHTML:(CLStream *) stream
{
  [self writeHTML:stream withHeaders:YES];
  return;
}

-(void) checkForErrors
{
  if (![[[cl_errorText value] description] length] &&
      ![[[cl_infoText value] description] length]) {
    [cl_messageBlock setValue:nil];
    cl_errorText = cl_infoText = nil;
  }

  return;
}

-(BOOL) needsLoadEvent:(CLArray *) anArray
{
  int i, j;
  id anObject;


  for (i = 0, j = [anArray count]; i < j; i++) {
    anObject = [anArray objectAtIndex:i];
    if ([anObject isKindOfClass:[CLChainedSelect class]])
      return YES;

    if ([anObject respondsTo:@selector(value)] &&
	[[anObject value] isKindOfClass:[CLArray class]] &&
	[self needsLoadEvent:[anObject value]])
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
  int i, j, k;
  CLStream *stream2;
  char *data;
  int gz = NO;
  CLArray *keys;
  id anObject;
  CLAccount *anAccount = nil;


  [self checkForErrors];
  
  if ([CLGenericRecord model])
    anAccount = [[[CLManager manager] activeSession] account];
  if (!anAccount)
    [[self objectWithID:@"cl_logoutControl"] setVisible:NO];
  else
    [[self objectWithID:@"cl_loginControl"] setVisible:NO];

  stream2 = CLOpenMemory(NULL, 0, CL_WRITEONLY);
  CLWriteHTMLObject(stream2, preHeader);
  
  CLPrintf(stream2, @"<HTML>\n");

  CLPrintf(stream2, @"<HEAD>\n");
  if (title) {
    CLPrintf(stream2, @"<TITLE>");
    CLWriteHTMLObject(stream2, [title value]);
    CLPrintf(stream2, @"</TITLE>\n");
  }

  {
    CLString *baseURL, *baseDir, *aString;
    CLString *documentRoot;


    /* Lame, lame, lame. I have to write out a full URL into the BASE
       tag, not a relative one. */

    documentRoot = [CLString stringWithUTF8String:getenv("DOCUMENT_ROOT")];
    
    baseURL = [CLServerURL stringByAppendingString:CLWebPath];
    if ([filename hasPathPrefix:documentRoot]) {
      baseURL = CLServerURL;
      baseDir = [filename stringByDeletingLastPathComponent];
      baseDir = [baseDir stringByDeletingPathPrefix:documentRoot];
      baseDir = [@"/" stringByAppendingPathComponent:baseDir];
      if ([CLDelegate respondsTo:@selector(page:willUseBaseDirectory:)] &&
	  (aString = [CLDelegate page:self willUseBaseDirectory:baseDir]))
	baseDir = aString;
      if ([baseDir length])
	baseURL = [baseURL stringByAppendingPathComponent:baseDir];
      baseURL = [baseURL stringByAppendingPathComponent:@"/"];
    }
    CLPrintf(stream2, @"<BASE HREF=\"%@\">\n", baseURL);
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
    keys = [bodyAttributes allKeys];
    for (i = 0, j = [keys count]; i < j; i++) {
      anObject = [keys objectAtIndex:i];
      /* Not using hasPrefix: because I need case insensitive */
      if ([anObject length] >= 3 && ![anObject compare:@"CL_" options:CLCaseInsensitiveSearch
					       range:CLMakeRange(0, 3)])
	continue;
      CLPrintf(stream2, @" %@=\"%@\"", anObject,
	       [[bodyAttributes objectForKey:anObject] entityEncodedString]);
    }
    CLPrintf(stream2, @">\n");
  }

  CLWriteHTMLObject(stream2, body);

  if (!frames)
    CLPrintf(stream2, @"</BODY>\n");
  CLPrintf(stream2, @"</HTML>\n");

  /* Gotta write the headers to do gzip. Without the headers, we won't
     know anymore that it has been gzipped! */
  gz = showHeaders && CLBrowserAcceptsGzip();

  CLGetMemoryBuffer(stream2, &data, &i, &j);
  if (output)
    *output = [CLData dataWithBytes:data length:i];

  if (gz) {
    CLData *aData;


    if (!CLDeflate(data, i, 9, &aData)) {
      if (showHeaders) {
	CLPrintf(stream, @"Status: %u %@\r\n", status, [self statusString]);
	CLPrintf(stream, @"Content-Type: text/html; charset=UTF-8\r\n");
	CLPrintf(stream, @"Content-Length: %u\r\n", [aData length]);
	CLPrintf(stream, @"Cache-Control: must-revalidate\r\n");
	//CLPrintf(stream, @"Cache-Control: no-store\r\n");
	//CLPrintf(stream, @"Expires: -1\r\n");
	CLPrintf(stream, @"Content-Encoding: gzip\r\n");
	for (i = 0, j = [CLCookies count]; i < j; i++)
	  if (![[CLCookies objectAtIndex:i] isFromBrowser])
	    CLPrintf(stream, @"Set-Cookie: %@\r\n",
		     [[CLCookies objectAtIndex:i] cookieString]);
	CLPrintf(stream, @"\r\n");
      }

      CLWrite(stream, [aData bytes], [aData length]);
    }
    else
      gz = 0;
  }

  if (!gz) {
    if (showHeaders) {
      CLPrintf(stream, @"Status: %u %@\r\n", status, [self statusString]);
      CLPrintf(stream, @"Content-Type: text/html; charset=UTF-8\r\n");
      CLPrintf(stream, @"Content-Length: %i\r\n", i);
      CLPrintf(stream, @"Cache-Control: must-revalidate\r\n");
      //CLPrintf(stream, @"Cache-Control: no-store\r\n");
      //CLPrintf(stream, @"Expires: -1\r\n");
      for (j = 0, k = [CLCookies count]; j < k; j++)
	if (![[CLCookies objectAtIndex:j] isFromBrowser])
	  CLPrintf(stream, @"Set-Cookie: %@\r\n",
		   [[CLCookies objectAtIndex:j] cookieString]);
      CLPrintf(stream, @"\r\n");
    }
    
    CLWrite(stream, data, i);
  }
  
  CLCloseMemory(stream2, CL_FREEBUFFER);
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

    if ([anObject respondsTo:@selector(value)] &&
	[[anObject value] isKindOfClass:[CLArray class]] &&
	(anObject = [self allIDs:[anObject value]]))
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
  char *data;
  int i, j;
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
    
    stream = CLOpenMemory(NULL, 0, CL_WRITEONLY);
    [self writeHTML:stream withHeaders:YES output:output];
    CLGetMemoryBuffer(stream, &data, &i, &j);
    fwrite(data, 1, i, stdout);
    CLCloseMemory(stream, CL_FREEBUFFER);
    fflush(stdout);
  }

  return;
}

-(CLData *) htmlForBody
{
  CLStream *stream;
  CLData *aData;


  stream = CLOpenMemory(NULL, 0, CL_WRITEONLY);
  CLWriteHTMLObject(stream, body);
  aData = CLGetData(stream);
  CLCloseMemory(stream, CL_FREEBUFFER);
  return aData;
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

/* Extensions pulled from FZPage */

-(id) objectForVariable:(CLString *) aVariable fromArray:(CLArray *) anArray
{
  int i, j;
  id anObject;


  for (i = 0, j = [anArray count]; i < j; i++) {
    anObject = [anArray objectAtIndex:i];
    if ([anObject respondsTo:@selector(attributes)] &&
	[[[anObject attributes] objectForCaseInsensitiveString:@"CL_VARNAME"]
	  isEqualToString:aVariable])
      return anObject;

    if ([anObject respondsTo:@selector(value)] &&
	[[anObject value] isKindOfClass:[CLArray class]] &&
	(anObject = [self objectForVariable:aVariable fromArray:[anObject value]]))
      return anObject;
  }
  
  return nil;
}

-(id) objectForVariable:(CLString *) aVariable
{
  id anObject;

  
  if (!(anObject = [self objectForVariable:aVariable fromArray:body]))
    if (!(anObject = [self objectForVariable:aVariable fromArray:header]))
      anObject = [self objectForVariable:aVariable fromArray:preHeader];
  
  return anObject;
}

-(id) objectWithID:(CLString *) idString fromArray:(CLArray *) anArray
{
  int i, j;
  id anObject;
  CLString *aString;
  BOOL found;


  for (i = 0, j = [anArray count]; i < j; i++) {
    anObject = [anArray objectAtIndex:i];
    if ([anObject respondsTo:@selector(attributes)]) {
      if ([[[anObject attributes] objectForCaseInsensitiveString:@"ID"]
	  isEqualToString:idString])
	return anObject;
      if ((aString = [[anObject attributes] objectForCaseInsensitiveString:@"CL_ID"])) {
	aString = [anObject objectValueForSpecialBinding:aString allowConstant:NO
						   found:&found wasConstant:NULL];
	if ([aString isEqualToString:idString])
	  return anObject;
      }
    }

    if ([anObject respondsTo:@selector(value)] &&
	[[anObject value] isKindOfClass:[CLArray class]] &&
	(anObject = [self objectWithID:idString fromArray:[anObject value]]))
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

-(void) setInstanceVariable:(CLString *) aVariable
{
  id anObject;

  
  if ((anObject = [self objectForVariable:aVariable]))
    CLObjectSetInstanceVariable(self, [aVariable UTF8String], anObject);
  return;
}

-(void) appendErrorString:(CLString *) aString
{
  [cl_errorText addObject:@"<LI CLASS=cl_errorText>"];
  [cl_errorText addObject:aString];
  return;
}

-(void) appendInfoString:(CLString *) aString
{
  [cl_infoText addObject:@"<LI CLASS=cl_infoText>"];
  [cl_infoText addObject:aString];
  return;
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
      if (aValue && ![aValue isKindOfClass:[CLNull class]])
	[mString appendFormat:@"%c%@=%@", c, [[aKey description]
					       stringByAddingPercentEscapes],
		 [[aValue description] stringByAddingPercentEscapes]];
      else
	[mString appendFormat:@"%c%@", c, [[aKey description] stringByAddingPercentEscapes]];

      c = '&';      
    }
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


  aControl = [[CLControl alloc] init];
  aTarget = [[CLPageTarget alloc] initFromPath:aFilename];
  [aControl setTarget:aTarget];
  [aControl setAction:@selector(showPage:)];
  aString = [aControl generateURL];
  [aControl release];
  [aTarget release];

  CLRedirectBrowser(aString, includeQuery, 303);
}
