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

#import "CLEmailMessage.h"
#import "CLEmailHeader.h"
#import "CLMutableString.h"
#import "CLArray.h"
#import "CLDictionary.h"
#import "CLStream.h"
#import "CLManager.h"
#import "CLString.h"
#import "CLPage.h"
#import "CLData.h"

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

@implementation CLEmailMessage

-(id) init
{
  return [self initFromFile:nil owner:nil];
}

-(id) initFromFile:(CLString *) aFilename owner:(id) anOwner
{
  CLString *aString;
  CLArray *dirs = nil;

  
  [super init];
  header = nil;
  body = nil;
  sendmailOptions = nil;

  if ([CLDelegate respondsTo:@selector(additionalPageDirectories)])
    dirs = [CLDelegate additionalPageDirectories];

  if (aFilename) {
    aString = CLFullPathForFile(aFilename, [CLArray arrayWithObjects:@"hdr", nil], dirs);
    header = [[CLEmailHeader alloc]
	       initFromString:
		 [CLString stringWithContentsOfFile:aString encoding:CLUTF8StringEncoding]];
    body = [[CLPage pageFromFile:aFilename owner:anOwner] retain];
  }
  
  return self;
}

-(void) dealloc
{
  [header release];
  [body release];
  [sendmailOptions release];
  [super dealloc];
  return;
}

-(id) copy
{
  CLEmailMessage *aCopy = [super copy];


  aCopy->header = [header copy];
  aCopy->body = [body copy];
  return aCopy;
}

-(void) send
{
  CLString *aString;
  CLStream *oFile;
  CLData *aData;
  CLString *options = sendmailOptions;


  if (!options)
    options = @"";
  
  oFile = [CLStream openTemporaryFile:@"clmsg.XXXXXX"];
  [header updateBindings:[body datasource]];
  CLPrintf(oFile, @"%@", [header description]);
  if (getenv("REMOTE_ADDR"))
    CLPrintf(oFile, @"X-Remote-Addr: %s\n", getenv("REMOTE_ADDR"));
  CLPrintf(oFile, @"\n");
  [body updateBindings];
  aData = [body htmlForBody];
  [oFile writeData:aData];
  [oFile close];
  aString = [CLString stringWithFormat:@"(/usr/lib/sendmail -t %@ < %@ ; rm %@) &",
		      options, [oFile path], [oFile path]];
  system([aString UTF8String]);
  
  return;
}

-(void) setSendmailOptions:(CLString *) aString
{
  [sendmailOptions release];
  sendmailOptions = [aString copy];
  return;
}

@end

void CLSendEmailUsingTemplate(CLDictionary *aDict, CLString *aFilename,
			      CLString *sendmailOptions)
{
  CLMutableString *mString;
  CLString *aString;
  CLArray *anArray;
  int i, j;
  CLStream *oFile;


  if (![aFilename isAbsolutePath])
    aFilename = [CLAppPath stringByAppendingPathComponent:aFilename];

  if (!sendmailOptions)
    sendmailOptions = @"";
  
  mString = [[CLString stringWithContentsOfFile:aFilename encoding:CLUTF8StringEncoding]
	      mutableCopy];

  anArray = [aDict allKeys];
  for (i = 0, j = [anArray count]; i < j; i++) {
    aString = [anArray objectAtIndex:i];
    [mString replaceOccurrencesOfString:aString withString:[aDict objectForKey:aString]];
  }

  oFile = [CLStream openTemporaryFile:@"clmsg.XXXXXX"];
  CLPrintf(oFile, @"%@", mString);
  [oFile close];
  aString = [CLString stringWithFormat:@"/usr/lib/sendmail -t %@ < %@",
		      sendmailOptions, [oFile path]];
  system([aString UTF8String]);
  [oFile remove];
#if DEBUG_RETAIN
    id self = nil;
#endif
  [mString release];
  
  return;
}

