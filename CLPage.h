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

#import <ClearLake/CLObject.h>
#import <ClearLake/CLStream.h>

@class CLMutableArray, CLMutableDictionary, CLString,
  CLArray, CLDictionary, CLBlock, CLControl;

@interface CLPage:CLObject <CLCopying>
{
  CLMutableArray *body, *header, *preHeader;
  CLMutableDictionary *bodyAttributes;
  CLBlock *title;
  CLString *filename;
  CLMutableArray *fileStack, *usedFiles;
  CLUInteger status;
  BOOL frames;

  CLBlock *cl_errorText, *cl_infoText;
  CLBlock *cl_messageBlock;
  
  id owner, datasource;
}

+(CLPage *) pageFromFile:(CLString *) aFilename owner:(id) anOwner;
+(CLString *) findFile:(CLString *) aFilename directory:(CLString *) aDir;
+(CLString *) findFile:(CLString *) aFilename directories:(CLArray *) anArray;
+(CLMutableArray *) objectsForTags;

-(id) init;
-(id) initFromTitle:(CLString *) aTitle; /* This is the designated initializer */
-(id) initFromFile:(CLString *) aFilename owner:(id) anOwner;
-(id) initFromString:(CLString *) htmlString owner:(id) anOwner;
-(id) initFromString:(CLString *) htmlString owner:anOwner filename:(CLString *) aFilename;
-(void) dealloc;

-(void) addObject:(id) anObject;
-(void) appendString:(CLString *) aString;
-(void) addObjectToHeader:(id) anObject;
-(void) appendStringToHeader:(CLString *) aString;
-(CLArray *) body;
-(CLArray *) header;
-(CLArray *) preHeader;
-(id) owner;
-(id) datasource;
-(id) datasourceForBinding:(CLString *) aBinding;
-(void) updateBindings;
-(CLString *) filename;
-(CLUInteger) status;
-(void) setStatus:(CLUInteger) aValue;

-(CLBlock *) title;
-(void) setTitle:(CLString *) aString;

-(void) writeHTML:(CLStream *) stream;
-(void) writeHTML:(CLStream *) stream withHeaders:(BOOL) showHeaders;
-(void) writeHTML:(CLStream *) stream withHeaders:(BOOL) showHeaders
	   output:(CLData **) output;
-(void) display;
-(void) display:(CLData **) output;
-(CLData *) htmlForBody;

-(CLDictionary *) bodyAttributes;
-(CLArray *) usedFiles;

@end

@interface CLPage (CLPageExtensions)

-(id) objectForVariable:(CLString *) aVariable;
-(id) objectWithID:(CLString *) idString;
-(void) setInstanceVariable:(CLString *) aVariable;
-(void) appendErrorString:(CLString *) aString;
-(void) appendInfoString:(CLString *) aString;

@end

@protocol CLPageDelegate
-(BOOL) pageShouldDisplay:(CLPage *) aPage;
-(void) pageWillDisplay:(CLPage *) aPage;
-(CLArray *) additionalPageDirectories;
-(CLString *) page:(CLPage *) aPage willUseBaseDirectory:(CLString *) aDir;
@end

#if 0
extern void CLAllowFrom(CLString *aURL);
extern void CLRedirectTo(CLString *aURL);
#endif
extern BOOL CLBrowserAcceptsGzip();
extern void CLSetDelegate(id anObject);

@protocol CLRequest
-(void) performAction;
-(void) showPage:sender;
@end

extern void CLRedirectBrowser(CLString *newURL, BOOL includeQuery, int status);
extern void CLRedirectBrowserToPage(CLString *aFilename, BOOL includeQuery);
extern CLMutableArray *CLPageObjects;
