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

#import "CLStandardContent.h"
#import "CLWikiString.h"
#import "CLWikiImage.h"
#import "CLWikiLink.h"
#import "CLWikiMedia.h"
#import "CLStandardContentImage.h"
#import "CLStandardContentFile.h"
#import "CLStandardContentCategory.h"
#import "CLMutableString.h"
#import "CLCategory.h"
#import "CLPage.h"
#import "CLForm.h"
#import "CLMutableArray.h"
#import "CLOption.h"
#import "CLNumber.h"
#import "CLDictionary.h"
#import "CLRelationship.h"
#import "CLCharacterSet.h"
#import "CLData.h"
#import "CLMutableDictionary.h"
#import "CLSortDescriptor.h"
#import "CLEditingContext.h"
#import "CLRecordDefinition.h"
#import "CLCachedImage.h"
#import "CLInput.h"
#import "CLFileType.h"
#import "CLBlock.h"
#import "CLClassConstants.h"

#define FIELD_CAT		@"cl_sc"
#define FIELD_CATDEPTH		FIELD_CAT @"_depth"
#define FIELD_CATOTHER		FIELD_CAT @"_other"
#define FIELD_NUMCAT		FIELD_CAT @"_numcat"
#define FIELD_JOINCAT		FIELD_CAT @"_join"
#define FIELD_REMOVECAT		FIELD_CAT @"_remove"

#define FIELD_NUMWKIMG		FIELD_CAT @"_numwkimages"
#define FIELD_WKIMAGE		FIELD_CAT @"_wkimage"
#define FIELD_WKIMAGEID		FIELD_CAT @"_wkid"

#define FIELD_NUMWKLINK		FIELD_CAT @"_numwklinks"
#define FIELD_WKLINKID		FIELD_CAT @"_href"

#define FIELD_NUMWKMEDIA	FIELD_CAT @"_numwkmedia"
#define FIELD_WKMEDIA		FIELD_CAT @"_wkmedia"
#define FIELD_WKMEDIAID		FIELD_CAT @"_wkid"

#define FIELD_FILE		FIELD_CAT @"_file"
#define FIELD_FILEID		FIELD_CAT @"_fileid"
#define FIELD_FCAPTION		FIELD_CAT @"_fcaption"
#define FIELD_FTYPE		FIELD_CAT @"_ftype"
#define FIELD_UPDFILE		FIELD_CAT @"_updatefile"
#define FIELD_UPLFILE		FIELD_CAT @"_uploadfile"
#define FIELD_NUMFILES		FIELD_CAT @"_numfiles"
#define FIELD_REMOVEFILE	FIELD_CAT @"_fremove"
#define FIELD_DELFILES		FIELD_CAT @"_delfiles"

//#define FIELD_NUMGALLERY	FIELD_CAT @"_numgallery"
#define FIELD_GALLERYID		FIELD_CAT @"_galid"
#define FIELD_GALLERYIMAGE	FIELD_CAT @"_galimage"
#define FIELD_GALLERYORDER	FIELD_CAT @"_galorder"
#define FIELD_GALLERYCAPTION	FIELD_CAT @"_galcaption"
#define FIELD_GALLERYCREDIT	FIELD_CAT @"_galcredit"
#define FIELD_REMOVEGALLERY	FIELD_CAT @"_galremove"
#define FIELD_GALLERYUPDATE	FIELD_CAT @"_galupdate"
#define FIELD_GALLERYUPLOAD	FIELD_CAT @"_galupload"
#define FIELD_DELIMAGES		FIELD_CAT @"_delimages"

#define FIELD_PARENT		FIELD_CAT @"_parent"
#define FIELD_PARENTDEPTH	FIELD_PARENT @"_depth"

#define MAX_URLLENGTH		20

@implementation CLStandardContent

+(void) linkerIsBorked
{
  CLStandardContentImage *image = nil;


  [image position];  
  return;
}

+(CLString *) urlTitleFromString:(CLString *) aString mode:(int) urlMode
{
  CLMutableString *mString;
  CLCharacterSet *aSet, *notSet;
  CLRange aRange, aRange2;
  CLData *aData;


  aData = [aString dataUsingEncoding:CLASCIIStringEncoding allowLossyConversion:YES];
  mString = [CLMutableString stringWithData:aData encoding:CLASCIIStringEncoding];
  if (urlMode == CLSCDashMode) {
    mString = [[[mString lowercaseString] mutableCopy] autorelease];
    [mString replaceOccurrencesOfString:@" " withString:@"-"];
    aSet = [CLCharacterSet characterSetWithCharactersInString:
			     @"-0123456789"
			   "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
			   "abcdefghijklmnopqrstuvwxyz"];
  }
  else {
    [mString replaceOccurrencesOfString:@" " withString:@"_"];
    aString = [mString upperCamelCaseString];
    mString = [[aString mutableCopy] autorelease];
    aSet = [CLCharacterSet characterSetWithCharactersInString:
			     @"0123456789"
			   "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
			   "abcdefghijklmnopqrstuvwxyz"];
  }

  notSet = [aSet invertedSet];
  aRange = [mString rangeOfCharacterFromSet:notSet];
  while (aRange.length) {
    aRange2.location = CLMaxRange(aRange);
    aRange2.length = [mString length] - aRange2.location;
    aRange2 = [mString rangeOfCharacterFromSet:aSet options:0 range:aRange2];
    if (aRange2.length)
      aRange.length = aRange2.location - aRange.location;
    [mString replaceCharactersInRange:aRange withString:@""];
    if (aRange2.length) {
      aRange2.location = aRange.location;
      aRange2.length = [mString length] - aRange2.location;
      aRange = [mString rangeOfCharacterFromSet:notSet options:0 range:aRange2];
    }
    else
      aRange.length = 0;
  }

  return mString;
}
  
-(void) dealloc
{
  [body release];
  [_removedCategories release];
  [super dealloc];
  return;
}

-(void) setBody:(CLString *) aString
{
  [self willChange];
  [body release];
  body = [[CLWikiString alloc] initFromString:aString];
  return;
}

#if 0
-(void) delete:(id) sender
{
  [sender setPage:[[[CLPage alloc] initFromFile:PAGE_CONFIRM owner:self] autorelease]];

  if ([sender isKindOf:CLFormClass]) {
    if ([sender valueOfFieldNamed:FIELD_CONFIRM]) {
      [self deleteFromDatabase];
      [[[Controller alloc] init] showPage:sender];
    }
    else
      [self detail:sender];
  }
  
  return;
}
#endif

-(void) didDeleteFromDatabase
{
  [super didDeleteFromDatabase];
  [body unlinkImages];
  [body unlinkMedia];
  return;
}

-(id) topCategory
{
  return nil;
}

-(id) joinCategory:(CLCategory *) aCat
{
  id pCat;
  CLRelationship *aRelationship;

      
  aRelationship = [[_recordDef relationships] objectForKey:@"categories"];
  pCat = [[[CLEditingContext classForTable:[aRelationship theirTable]] alloc]
	   initFromDictionary:nil table:[aRelationship theirTable]];
  [pCat addObject:aCat toBothSidesOfRelationship:@"category"];
  [self addObject:pCat toBothSidesOfRelationship:@"categories"];
  [pCat autorelease];

  return pCat;
}
  
-(void) addCategory:(id) sender
{
  int i, j, oid, depth;
  id anObject = [self topCategory];
  CLCategory *aCat = nil, *newCat = nil;
  CLString *aString;
  CLArray *anArray;


  if ([anObject isKindOfClass:[CLCategory class]])
    aCat = anObject;
  
  depth = [[sender valueOfFieldNamed:FIELD_CATDEPTH] intValue];
  for (i = 0; i < depth; i++) {
    aString = [sender valueOfFieldNamed:[CLString stringWithFormat:FIELD_CAT @"_%i", i+1]];
    if (![aString length])
      break;

    oid = [aString intValue];
    if (!oid) {
      CLRange aRange;


      aRange = [aString rangeOfString:@","];
      if (!aRange.length)
	break;
      anArray = [[aString substringFromIndex:CLMaxRange(aRange)] decodePropertyList];
      if ([aCat isKindOfClass:[CLCategory class]])
	newCat = [aCat childWithTitle:[anArray lastObject]];
      else
	newCat = [CLCategory categoryWithTitle:[anArray lastObject] andParentID:0];

      if (!newCat)
	break;

      aCat = newCat;
    }
    else if (oid < 0) {
      if (!(aString = [sender valueOfFieldNamed:FIELD_CATOTHER])) {
#if 0
	[[sender page] appendErrorString:@"You must fill in a new category name"];
#endif
	return;
      }

      newCat = [[[CLCategory alloc] init] autorelease];
      [newCat setTitle:aString];
      [newCat createUrlTitleFromTitle];
      if (aCat)
	[newCat addObject:aCat toBothSidesOfRelationship:@"parent"];
      aCat = newCat;
      break;
    }
    else {
      newCat = [CLCategory categoryWithID:oid];
      if (!aCat || [newCat isChildOfCategory:aCat])
	aCat = newCat;
      else
	break;
    }
  }

  if (aCat) {
    anArray = [self categories];
    for (i = 0, j = [anArray count]; i < j; i++)
      if ([[[anArray objectAtIndex:i] category] isEqual:aCat])
	break;
    if (i == j)
      [self joinCategory:aCat];
  }

  return;
}

-(void) removeCategory:(id) sender
{
  CLMutableArray *mArray;
  CLString *aString;
  int i, j, k, l;
  int oid;


  mArray = (CLMutableArray *) [self categories];
  j = [[sender valueOfFieldNamed:FIELD_NUMCAT] intValue];
  for (i = 0; i < j; i++) {
    aString = [CLString stringWithFormat:@"cl_sc_catremoveid_%i", i+1];
    if ((oid = [[sender valueOfFieldNamed:aString] intValue])) {
      for (k = 0, l = [mArray count]; k < l; k++)
	if (oid == [[[mArray objectAtIndex:k] category] objectID]) {
	  if (!_removedCategories)
	    _removedCategories = [[CLMutableArray alloc] init];
	  [_removedCategories addObject:[mArray objectAtIndex:k]];
	  break;
	}
    }
  }

  return;
}

-(CLStandardContentImage *) imageWithID:(int) oid
{
  int i, j;
  CLArray *anArray = [self images];
  CLStandardContentImage *anImage;


  for (i = 0, j = [anArray count]; i < j; i++) {
    anImage = [anArray objectAtIndex:i];
    if ([anImage objectID] == oid)
      return anImage;
  }

  return nil;
}

-(CLOriginalImage *) wikiImageWithID:(int) oid
{
  int i, j;
  CLArray *anArray = [[self body] images];
  CLOriginalImage *anImage;


  for (i = 0, j = [anArray count]; i < j; i++) {
    anImage = (CLOriginalImage *) [[anArray objectAtIndex:i] image];
    if ([anImage objectID] == oid)
      return anImage;
  }

  return nil;
}

-(CLStandardContentFile *) fileWithID:(int) oid
{
  int i, j;
  CLArray *anArray = [self files];
  CLStandardContentFile *aFile;


  for (i = 0, j = [anArray count]; i < j; i++) {
    aFile = [anArray objectAtIndex:i];
    if ([aFile objectID] == oid)
      return aFile;
  }

  return nil;
}

-(CLArray *) sortedImages
{
  return [[self images] sortedArrayUsingSelector:@selector(comparePosition:)];
}

-(id) firstImage
{
  CLArray *anArray = [self sortedImages];


  if (![anArray count])
    anArray = [[self body] images];

  if ([anArray count])
    return [anArray objectAtIndex:0];
  
  return nil;
}

-(void) linkParent:(id) sender
{
  int i, oid, depth;
  id anObject = nil, newObject = nil;
  CLRelationship *aRelationship;
  id aClass;


  aRelationship = [[_recordDef relationships] objectForKey:@"parent"];
  aClass = [CLEditingContext classForTable:[aRelationship theirTable]];
  depth = [[sender valueOfFieldNamed:FIELD_PARENTDEPTH] intValue];
  for (i = 0; i < depth; i++) {
    if (!(oid = [[sender valueOfFieldNamed:
			   [CLString stringWithFormat:FIELD_PARENT @"_%i", i+1]] intValue]))
      break;

    newObject = [[self editingContext] loadObjectWithClass:aClass objectID:oid];
    if (!anObject || [newObject isChildOf:anObject]) {
      [anObject autorelease];
      anObject = newObject;
    }
    else {
      [newObject release];
      break;
    }
  }

  if ([anObject isChildOf:self])
    anObject = nil;
  if (anObject)
    [self addObject:anObject toBothSidesOfRelationship:@"parent"];
  else
    [self removeObject:[self parent] fromBothSidesOfRelationship:@"parent"];

  return;
}

-(CLArray *) findInputs:(CLArray *) anArray
{
  id anObject;
  int i, j;
  CLMutableArray *mArray;
  CLString *aString;


  mArray = [[CLMutableArray alloc] init];
  for (i = 0, j = [anArray count]; i < j; i++) {
    anObject = [anArray objectAtIndex:i];
    if ([anObject isKindOfClass:CLInputClass] &&
	(aString = [[anObject attributes] objectForCaseInsensitiveString:@"NAME"]))
      [mArray addObject:aString];

    if ([anObject respondsTo:@selector(content)] &&
	[[anObject content] isKindOfClass:CLArrayClass])
      [mArray addObjectsFromArray:[self findInputs:[((CLBlock *) anObject) content]]];
  }

  return [mArray autorelease];
}

-(int) validateForm:(id) sender
{
  int err = 0;


  {
    CLArray *anArray;
    int i, j, k, l;
    CLWikiImage *anImage;
    CLInput *aField;
    CLString *aString;
    CLPage *aPage;
    CLArray *fieldNames;
    int oid;


    /* FIXME - delete images that have been removed from body */ 
    anArray = [body images];

    j = [[sender valueOfFieldNamed:FIELD_NUMWKIMG] intValue];
    if (j) {
      aPage = [CLPage pageFromFile:@"CLWikiImage_editRow" owner:nil];
      fieldNames = [self findInputs:[aPage body]];

      if (![fieldNames count])
	fieldNames = [CLArray arrayWithObjects:FIELD_WKIMAGEID, FIELD_WKIMAGE, nil];
    
      for (i = 0; i < j; i++) {
	oid = [[sender valueOfFieldNamed:[CLString stringWithFormat:
						    FIELD_WKIMAGEID "_%i", i+1]] intValue];
	for (k = 0, l = [anArray count]; k < l; k++) {
	  anImage = [anArray objectAtIndex:k];
	  if ([[anImage imageID] intValue] == oid)
	    break;
	}
	if (k < l) {
	  for (k = 0, l = [fieldNames count]; k < l; k++) {
	    aString = [fieldNames objectAtIndex:k];
	    aField = [sender fieldNamed:[CLString stringWithFormat:@"%@_%i", aString, i+1]];
	    if ([aString isEqualToString:FIELD_WKIMAGE]) {
	      if ([aField value] && ![anImage setImageFromField:aField])
		err++;
	    }
	    else if ([aString isEqualToString:FIELD_WKIMAGEID])
	      continue;
	    else
	      [anImage setObject:[aField value] forAttribute:aString];
	  }
	}
      }
    }

    for (i = 0, j = [anArray count]; i < j; i++)
      if (![[anArray objectAtIndex:i] imageID])
	err++;
  }

  {
    CLArray *anArray;
    int i, j, k, l;
    CLWikiLink *aLink = nil;
    CLInput *aField;
    CLString *aString;
    CLPage *aPage;
    CLArray *fieldNames;


    /* FIXME - delete images that have been removed from body */ 
    anArray = [body links];

    j = [[sender valueOfFieldNamed:FIELD_NUMWKLINK] intValue];
    if (j) {
      aPage = [CLPage pageFromFile:@"CLWikiLink_editRow" owner:nil];
      fieldNames = [self findInputs:[aPage body]];
      [aPage release];
    
      for (i = 0; i < j; i++) {
	aString = [sender valueOfFieldNamed:[CLString stringWithFormat:
							FIELD_WKLINKID "_%i", i+1]];
	for (k = 0, l = [anArray count]; k < l; k++) {
	  aLink = [anArray objectAtIndex:k];
	  if ([aString isEqualToString:
			 [[aLink attributes] objectForCaseInsensitiveString:@"href"]])
	    break;
	}
	if (k == l) {
	  if (i < l)
	    aLink = [anArray objectAtIndex:i];
	  else
	    aLink = nil;
	}
	
	for (k = 0, l = [fieldNames count]; k < l; k++) {
	  aString = [fieldNames objectAtIndex:k];
	  aField = [sender fieldNamed:[CLString stringWithFormat:@"%@_%i", aString, i+1]];
	  [aLink setObject:[aField value] forAttribute:aString];
	}
      }
    }
  }

  {
    CLArray *anArray;
    int i, j, k, l;
    CLWikiMedia *aFile;
    CLInput *aField;
    CLString *aString;
    CLPage *aPage;
    CLArray *fieldNames;
    int oid;


    /* FIXME - delete media that has been removed from body */ 
    anArray = [body media];

    j = [[sender valueOfFieldNamed:FIELD_NUMWKMEDIA] intValue];
    if (j) {
      aPage = [CLPage pageFromFile:@"CLWikiMedia_editRow" owner:nil];
      fieldNames = [self findInputs:[aPage body]];
      [aPage release];
    
      for (i = 0; i < j; i++) {
	oid = [[sender valueOfFieldNamed:[CLString stringWithFormat:
						     FIELD_WKMEDIAID "_%i", i+1]] intValue];
	for (k = 0; k < j; k++) {
	  aFile = [anArray objectAtIndex:k];
	  if ([[aFile fileID] intValue] == oid)
	    break;
	}
	if (k == j)
	  aFile = [anArray objectAtIndex:i];
	
	for (k = 0, l = [fieldNames count]; k < l; k++) {
	  aString = [fieldNames objectAtIndex:k];
	  aField = [sender fieldNamed:[CLString stringWithFormat:@"%@_%i", aString, i+1]];
	  if ([aString isEqualToString:FIELD_WKMEDIA]) {
	    if ([aField value] && ![aFile setFileFromField:aField])
	      err++;
	  }
	  else if ([aString isEqualToString:FIELD_WKMEDIAID])
	    continue;
	  else
	    [aFile setObject:[aField value] forAttribute:aString];
	}
      }
    }

    for (i = 0, j = [anArray count]; i < j; i++)
      if (![[anArray objectAtIndex:i] fileID])
	err++;
  }

  if ([sender fieldNamed:FIELD_JOINCAT]) {
    [self addCategory:sender];
    err++;
  }

  if ([sender fieldNamed:FIELD_REMOVECAT]) {
    [self removeCategory:sender];
    err++;
  }

  {
    int i, j;
    CLMutableArray *mArray;
    CLArray *anArray;
    id anObject;
    CLStandardContentImage *anImage;
    CLString *aString;
    CLInput *aField;

    
    mArray = [[CLMutableArray alloc] init];
    /* Usings names of all fields because in theory uploadImage could
       return two fields with the same index and the overall counter
       could be short. */
    anArray = [sender allFields];
    for (i = 0, j = [anArray count]; i < j; i++) {
      aField = [anArray objectAtIndex:i];
      aString = [[aField attributes] objectForCaseInsensitiveString:@"NAME"];
      if ([aString hasPrefix:FIELD_GALLERYID @"_"])
	[mArray addObject:[CLNumber numberWithInt:[[aField value] intValue]]];
    }

    anArray = [self images];
    for (i = [anArray count]; i > 0; i--) {
      anImage = [anArray objectAtIndex:i-1];
      anObject = [CLNumber numberWithInt:[anImage objectID]];
      if (![mArray containsObject:anObject])
	[self removeObject:anImage fromBothSidesOfRelationship:@"images"];
    }

    [mArray release];
  }
  
  if ([sender valueOfFieldNamed:FIELD_GALLERYIMAGE]) {
    CLRelationship *aRelationship;
    id newImage;

      
    aRelationship = [[_recordDef relationships] objectForKey:@"images"];
    newImage = [[CLEditingContext classForTable:[aRelationship theirTable]]
		 imageFromField:[sender fieldNamed:FIELD_GALLERYIMAGE]
		 table:[aRelationship theirTable]];
    [newImage setCaption:[sender valueOfFieldNamed:FIELD_GALLERYCAPTION]];
    if ([newImage hasFieldNamed:@"credit"])
      [newImage setCredit:[sender valueOfFieldNamed:FIELD_GALLERYCREDIT]];
    [newImage setPosition:[[self images] count] + 1];
    [self addObject:newImage toBothSidesOfRelationship:@"images"];
    [[self editingContext] saveChanges];
  }
  
  {
    int i, j;
    int oid, newPos;
    CLStandardContentImage *anImage;
    CLString *aField, *fieldIndex;
    CLArray *anArray;


    anArray = [sender fieldNames];
    for (i = 0, j = [anArray count]; i < j; i++) {
      aField = [anArray objectAtIndex:i];
      if ([aField hasPrefix:FIELD_GALLERYID]) {
	fieldIndex = [aField substringFromIndex:[FIELD_GALLERYID length]];
	oid = [[sender valueOfFieldNamed:aField] intValue];
	if (!(anImage = [self imageWithID:oid]) && oid && ![self wikiImageWithID:oid]) {
	  /* plist reconstruction deleted it, put it back */
	  CLRelationship *aRelationship;

      
	  aRelationship = [[_recordDef relationships] objectForKey:@"images"];
	  anImage = [[self editingContext] loadObjectWithClass:
			   [CLEditingContext classForTable:[aRelationship theirTable]]
						 objectID:oid];
	  [self addObject:anImage toBothSidesOfRelationship:@"images"];
	}
	newPos = [[sender valueOfFieldNamed:
			    [CLString stringWithFormat:FIELD_GALLERYORDER @"%@",
				      fieldIndex]] intValue];
	if (newPos)
	  [anImage setPosition:newPos];
	[anImage setCaption:[sender valueOfFieldNamed:
				      [CLString stringWithFormat:
						  FIELD_GALLERYCAPTION @"%@",
						fieldIndex]]];
	if ([anImage hasFieldNamed:@"credit"])
	  [anImage setCredit:[sender valueOfFieldNamed:
				       [CLString stringWithFormat:
						   FIELD_GALLERYCREDIT @"%@",
						 fieldIndex]]];
	
	if ([sender valueOfFieldNamed:[CLString stringWithFormat:
						  FIELD_REMOVEGALLERY @"%@", fieldIndex]])
	  [anImage setWillDelete:YES];
      }
    }
    
    if ([sender fieldNamed:FIELD_GALLERYUPDATE])
      err++;
  }

  {
    CLString *aString;
    CLArray *anArray;
    int i, j;
    CLStandardContentImage *anImage;
    

    if ((aString = [sender valueOfFieldNamed:FIELD_DELIMAGES])) {
      anArray = [aString decodeCSV];
      for (i = 0, j = [anArray count]; i < j; i++) {
	anImage = [self imageWithID:[[anArray objectAtIndex:i] intValue]];
	[anImage setWillDelete:YES];
      }
    }
  }

  if ([sender valueOfFieldNamed:FIELD_GALLERYORDER]) {
    CLArray *anArray;
    int i, j, oid;
    CLStandardContentImage *anImage;

    
    anArray = [[sender valueOfFieldNamed:FIELD_GALLERYORDER] decodeCSV];
    for (i = 0, j = [anArray count]; i < j; i++) {
      oid = [[anArray objectAtIndex:i] intValue];
      anImage = [self imageWithID:oid];
      [anImage setPosition:i+1];
    }
  }
    
  if ([sender fieldNamed:FIELD_GALLERYUPLOAD]) {
    err++;
  }
    
  if ([sender valueOfFieldNamed:FIELD_FILE]) {
    CLStandardContentFile *pf;
    CLRelationship *aRelationship;


    aRelationship = [[_recordDef relationships] objectForKey:@"files"];
    pf = [[CLEditingContext classForTable:[aRelationship theirTable]]
	    fileFromField:[sender fieldNamed:FIELD_FILE]
		    table:[aRelationship theirTable]];
    [pf setCaption:[sender valueOfFieldNamed:FIELD_FCAPTION]];
    if ([[sender valueOfFieldNamed:FIELD_FTYPE] intValue])
      [pf setType:[[self editingContext] loadObjectWithClass:CLFileTypeClass objectID:
			     [[sender valueOfFieldNamed:FIELD_FTYPE] intValue]]];
    [self addObject:pf toBothSidesOfRelationship:@"files"];
    [[self editingContext] saveChanges];
  }
    
  {
    int i, j;
    int oid, tid;
    CLStandardContentFile *aFile;


    for (i = 0, j = [[sender valueOfFieldNamed:FIELD_NUMFILES] intValue]; i < j; i++) {
      oid = [[sender valueOfFieldNamed:[CLString stringWithFormat:
						   FIELD_FILEID @"_%i", i+1]]
	      intValue];
      aFile = [self fileWithID:oid];
      [aFile setCaption:[sender valueOfFieldNamed:
				  [CLString stringWithFormat:
					      FIELD_FCAPTION @"_%i", i+1]]];
      if ((tid = [[sender valueOfFieldNamed:[CLString stringWithFormat:
							FIELD_FTYPE @"_%i", i+1]] intValue]))
	[aFile setType:[[self editingContext]
			 loadObjectWithClass:CLFileTypeClass objectID:tid]];
	
      if ([sender valueOfFieldNamed:[CLString stringWithFormat:
						FIELD_REMOVEFILE @"_%i", i+1]])
	[aFile setWillDelete:YES];
    }

    if ([sender fieldNamed:FIELD_UPDFILE])
      err++;
  }
    
  {
    CLString *aString;
    CLArray *anArray;
    int i, j;
    CLStandardContentFile *aFile;
    

    if ((aString = [sender valueOfFieldNamed:FIELD_DELFILES])) {
      anArray = [aString decodeCSV];
      for (i = 0, j = [anArray count]; i < j; i++) {
	aFile = [self fileWithID:[[anArray objectAtIndex:i] intValue]];
	[aFile setWillDelete:YES];
      }
    }
  }

  if ([sender fieldNamed:FIELD_UPLFILE]) {
    err++;
  }

  if ([sender fieldNamed:FIELD_PARENTDEPTH])
    [self linkParent:sender];
  
  {
    CLArray *anArray;
    int i, j;
      
      
    anArray = [self sortedImages];
    for (i = 0, j = [anArray count]; i < j; i++)
      [[anArray objectAtIndex:i] setPosition:i+1];
  }
  
  return err;
}

-(void) createUrlTitleFromString:(CLString *) aString
{
  CLString *titleString;
  int counter;
  CLArray *anArray;


  if ([self hasFieldNamed:@"urlTitle"]) {
    titleString = [[self class] urlTitleFromString:aString mode:CLSCCamelCaseMode];
    if ([titleString length] > MAX_URLLENGTH)
      titleString = [titleString substringToIndex:MAX_URLLENGTH];
  
    anArray = [[self editingContext] loadTableWithClass:[self class] qualifier:
				 [CLString stringWithFormat:@"url_title = '%@'", titleString]];
    counter = 1;
    while ([anArray count] && ([anArray count] > 1 ||
			       ![[anArray objectAtIndex:0] isEqual:self])) {
      counter++;
      anArray = [[self editingContext] loadTableWithClass:[self class] qualifier:
				   [CLString stringWithFormat:@"url_title = '%@%i'",
					     titleString, counter]];
    }
    if (counter > 1)
      titleString = [titleString stringByAppendingFormat:@"%i", counter];

    [self setUrlTitle:titleString];
  }

  return;
}
  
-(void) createUrlTitleFromTitle
{
  [self createUrlTitleFromString:[self title]];
  return;
}

-(BOOL) validateTitle:(id *) ioValue error:(CLString **) outError
{
  CLString *aString = *ioValue;


  if (![aString length]) {
    *outError = @"Please enter a title";
    return NO;
  }

  [self createUrlTitleFromString:aString];
  
  return YES;
}

-(id) doImageUpload:(id) sender
{
  CLRelationship *aRelationship;
  id newImage;
  CLArray *fields;
  int i, j;
  CLInput *aField;


  fields = [sender allFields];
  for (i = 0, j = [fields count]; i < j; i++) {
    aField = [fields objectAtIndex:i];
    if ([[aField value] isKindOfClass:[CLOriginalImage class]]) {
      aRelationship = [[_recordDef relationships] objectForKey:@"images"];
      newImage = [[CLEditingContext classForTable:[aRelationship theirTable]]
		   imageFromField:aField table:[aRelationship theirTable]];
      [newImage setPosition:[[self images] count] + 1];
      [self addObject:newImage toBothSidesOfRelationship:@"images"];
      [[self editingContext] saveChanges];
      return newImage;
    }
  }

  return nil;
}

-(void) uploadImage:(id) sender
{
  id newImage;
  CLPage *aPage;
  CLData *aData;
  CLBlock *aBlock;

  
  if ((newImage = [self doImageUpload:sender])) {
    [sender setPage:nil];
    if (!(aPage = [CLPage pageFromFile:[newImage findFileForKey:@"editGallery"]
				 owner:newImage]))
      aPage = [CLPage pageFromFile:[newImage findFileForKey:@"editRow"] owner:newImage];
    [aPage updateBindings];
    aBlock = [[CLBlock alloc] init];
    [aBlock setContent:[aPage body]];

    {
      CLMutableDictionary *mDict = [[CLMutableDictionary alloc] init];

      
      [aBlock autonumber:[aBlock content] position:[newImage position] replaced:mDict];
      [aBlock autonumber:[aBlock content] newIDs:mDict];
      [mDict release];
    }
    
    [aBlock release];
    aData = [aPage htmlForBody];
    printf("Content-Type: text/html\r\n");
    printf("Content-Length: %i\r\n", [aData length]);
    printf("\r\n");
    fwrite([aData bytes], [aData length], 1, stdout);
  }

  return;
}

-(void) uploadImageJSON:(id) sender
{
  id newImage;
  CLData *aData;
  CLMutableDictionary *mDict, *result;
  CLMutableArray *files;
  CLString *aString;

  
  if ((newImage = [self doImageUpload:sender])) {
    result = [CLMutableDictionary dictionary];
    files = [CLMutableArray array];
    [result setObject:files forKey:@"files"];
    mDict = [CLMutableDictionary dictionary];
    [mDict setObject:[[newImage image] filename] forKey:@"name"];
    [mDict setObject:[CLNumber numberWithUnsignedLongLong:[[newImage image] bytes]]
	      forKey:@"size"];
    [mDict setObject:[[newImage image] urlForMethod:@selector(view:)] forKey:@"url"];
    [mDict setObject:[[newImage image] urlForMethod:@selector(view:)] forKey:@"thumbnail_url"];
    [mDict setObject:@"#" forKey:@"delete_url"];
    [mDict setObject:@"DELETE" forKey:@"delete_type"];
    [files addObject:mDict];
    
    aString = [result json];
    aData = [aString dataUsingEncoding:CLUTF8StringEncoding];
    printf("Content-Type: text/plain\r\n");
    printf("Content-Length: %i\r\n", [aData length]);
    printf("\r\n");
    fwrite([aData bytes], [aData length], 1, stdout);
    return;
  }

  return;
}

-(id) doFileUpload:(id) sender
{
  CLRelationship *aRelationship;
  id newFile;
  CLArray *fields;
  int i, j;
  CLInput *aField;


  fields = [sender allFields];
  for (i = 0, j = [fields count]; i < j; i++) {
    aField = [fields objectAtIndex:i];
    if ([[aField value] isKindOfClass:[CLOriginalFile class]]) {
      aRelationship = [[_recordDef relationships] objectForKey:@"files"];
      newFile = [[CLEditingContext classForTable:[aRelationship theirTable]]
		   fileFromField:aField table:[aRelationship theirTable]];
      if ([newFile respondsTo:@selector(setPosition:)] || [newFile hasFieldNamed:@"position"])
	[newFile setPosition:[[self files] count] + 1];
      [self addObject:newFile toBothSidesOfRelationship:@"files"];
      [[self editingContext] saveChanges];
      return newFile;
    }
  }

  return nil;
}

-(void) uploadFile:(id) sender
{
  id newFile;
  CLPage *aPage;
  CLData *aData;
  CLBlock *aBlock;

  
  if ((newFile = [self doFileUpload:sender])) {
    [sender setPage:nil];
    if (!(aPage = [CLPage pageFromFile:[newFile findFileForKey:@"editGallery"]
				 owner:newFile]))
      aPage = [CLPage pageFromFile:[newFile findFileForKey:@"editRow"] owner:newFile];
    [aPage updateBindings];
    aBlock = [[CLBlock alloc] init];
    [aBlock setContent:[aPage body]];

    {
      CLMutableDictionary *mDict = [[CLMutableDictionary alloc] init];
      int pos;


      pos = [[self files] count];
      if ([newFile respondsTo:@selector(position)] || [newFile hasFieldNamed:@"position"])
	pos = [newFile position];
      [aBlock autonumber:[aBlock content] position:pos replaced:mDict];
      [aBlock autonumber:[aBlock content] newIDs:mDict];
      [mDict release];
    }
    
    [aBlock release];
    aData = [aPage htmlForBody];
    printf("Content-Type: text/html\r\n");
    printf("Content-Length: %i\r\n", [aData length]);
    printf("\r\n");
    fwrite([aData bytes], [aData length], 1, stdout);
  }

  return;
}

-(void) edit:(id) sender
{
  int err;


  [self replacePage:sender selector:_cmd];
  
  if ([sender isKindOfClass:CLFormClass]) {
    err = [self validateForm:sender];
    if (!err && ![sender wasError]) {
      [[self editingContext] saveChanges];
      if (![sender respondsTo:@selector(doVaction)] || ![sender doVaction])
	[self detail:sender];
    }
  }

  return;
}

-(CLArray *) positions
{
  CLMutableArray *mArray;
  CLString *aString;
  int i, j;

  
  if (!_positions) {
    mArray = [[CLMutableArray alloc] init];
    for (i = 0, j = [[self images] count]; i < j; i++) {
      aString = [CLString stringWithFormat:@"%i", i+1];
      [mArray addObject:[CLOption optionWithString:aString andValue:aString]];
    }
    _positions = mArray;
  }

  return _positions;
}

-(CLOption *) optionForObject:(id) anObject addOther:(BOOL) flag excludeObject:(id) exclude
		     selected:(id) selected
{
  CLOption *anOption = nil, *subOption;
  CLArray *anArray;
  int i, j;
  CLString *title, *value;


  if (anObject != exclude) {
    title = [anObject title];
    value = title;
    if ([anObject respondsTo:@selector(pathID)])
      value = [anObject pathID];
    anOption = [CLOption optionWithString:title andValue:value selected:
			[anObject isEqual:selected] || [selected isChildOf:anObject]];
    anArray = [anObject children];
    anArray = [anArray sortedArrayUsingDescriptors:
			 [CLSortDescriptor sortDescriptorsFromString:@"title"]];
    for (i = 0, j = [anArray count]; i < j; i++) {
      if ((subOption = [self optionForObject:[anArray objectAtIndex:i] addOther:flag
			     excludeObject:exclude selected:selected]))
	[anOption addSubOption:subOption];
    }
    if (flag || j)
      [anOption addSubOption:[CLOption optionWithString:@"-"
				       andValue:[CLNumber numberWithInt:0]
				       selected:[anObject isEqual:selected]]];
    if (flag)
      [anOption addSubOption:[CLOption optionWithString:@"Other:"
				       andValue:[CLNumber numberWithInt:-1]]];
  }
#if 0
  else
    anOption = [CLOption optionWithString:@"-" andValue:[CLNumber numberWithInt:0]];
#endif
  
  return anOption;
}

-(CLArray *) categoryOptions
{
  CLArray *anArray;
  int i, j;
  CLMutableArray *mArray;
  CLCategory *aCat;
  CLString *aString = nil;
  CLRelationship *aRelationship;
  CLRecordDefinition *def;
  id anObject;
  CLMutableString *mString;


  if ((anObject = [self topCategory])) {
    if ([anObject isKindOfClass:[CLCategory class]])
      aString = [CLString stringWithFormat:@"parent_id = %i", [anObject objectID]];
    else if ([anObject isKindOfClass:[CLArray class]]) {
      mString = [CLMutableString string];
      for (i = 0, j = [anObject count]; i < j; i++) {
	if ([mString length])
	  [mString appendString:@" or "];
	[mString appendFormat:@"id = %i", [[anObject objectAtIndex:i] objectID]];
      }
      aString = mString;
    }
  }

  if (!aString)
    aString = @"parent_id is null";

  aRelationship = [[_recordDef relationships] objectForKey:@"categories"];
  def = [CLEditingContext recordDefinitionForTable:[aRelationship theirTable]];
  aRelationship = [[def relationships] objectForKey:@"category"];
  def = [CLEditingContext recordDefinitionForTable:[aRelationship theirTable]];
  anArray = [[self editingContext] loadTableWithRecordDefinition:def qualifier:aString];
  anArray = [anArray sortedArrayUsingDescriptors:
		       [CLSortDescriptor sortDescriptorsFromString:@"title"]];
			       
  mArray = [[CLMutableArray alloc] init];
  for (i = 0, j = [anArray count]; i < j; i++) {
    aCat = [anArray objectAtIndex:i];
    [mArray addObject:[self optionForObject:aCat addOther:YES
			    excludeObject:nil selected:nil]];
  }

  if (![anObject isKindOfClass:[CLArray class]])
    [mArray addObject:[CLOption optionWithString:@"Other:"
					andValue:[CLNumber numberWithInt:-1]]];

  return [mArray autorelease];
}

-(CLArray *) parentOptions
{
  CLArray *anArray;
  int i, j;
  CLMutableArray *mArray;
  CLStandardContent *aContent;
  CLString *aString;
  CLRelationship *aRelationship;
  CLOption *anOption;


  /* FIXME - work like categories and allow a top category to define
     the top of the page hierarchy */
  aString = @"parent_id is null";
  aRelationship = [[_recordDef relationships] objectForKey:@"parent"];
  anArray = [[self editingContext] loadTableWithRecordDefinition:
				[CLEditingContext recordDefinitionForTable:
						    [aRelationship theirTable]]
				       qualifier:aString];
			       
  mArray = [[CLMutableArray alloc] init];
  for (i = 0, j = [anArray count]; i < j; i++) {
    aContent = [anArray objectAtIndex:i];
    if ((anOption = [self optionForObject:aContent addOther:NO
			  excludeObject:self selected:[self parent]]))
      [mArray addObject:anOption];
  }

  [mArray addObject:[CLOption optionWithString:@"-"
			      andValue:[CLNumber numberWithInt:0] selected:![self parent]]];
  
  return [mArray autorelease];
}

-(BOOL) isChildOf:(id) anObject
{
  id aParent, lastParent = self;
  int oid = [anObject objectID];
  CLArray *anArray;
  int i, j;


  if ([anObject isKindOfClass:[self class]]) {
    aParent = self;
    while (aParent) {
      if ([aParent objectID] == oid)
	return YES;
      lastParent = aParent;
      aParent = [aParent parent];
    }
  }

  if ([self hasFieldNamed:@"categories"] && [anObject isKindOfClass:CLCategoryClass]) {
    anArray = [lastParent categories];
    for (i = 0, j = [anArray count]; i < j; i++)
      if ([[[anArray objectAtIndex:i] category] isChildOfCategory:anObject])
	return YES;
  }

  return NO;
}

-(CLArray *) currentCategories
{
  CLMutableArray *mArray;


  if (![_removedCategories count])
    return [self categories];

  mArray = [[self categories] mutableCopy];
  [mArray removeObjectsInArray:_removedCategories];
  return [mArray autorelease];
}

-(BOOL) hasParent
{
  return !![self parent];
}

-(CLDictionary *) dictionary
{
  CLMutableDictionary *mDict;
  CLMutableArray *mArray;
  int i, j;
  CLStandardContentCategory *aCat;


  mDict = (CLMutableDictionary *) [super dictionary];
  if ([_removedCategories count]) {
    mArray = [[CLMutableArray alloc] init];
    for (i = 0, j = [_removedCategories count]; i < j; i++) {
      aCat = [_removedCategories objectAtIndex:i];
      [mArray addObject:[CLNumber numberWithInt:[[aCat category] objectID]]];
    }
    [mDict setObject:mArray forKey:@"removedCategories"];
    [mArray release];
  }
  
  return mDict;
}

-(void) willSaveToDatabase
{
  int i, j;
  CLStandardContentCategory *aCat;
  id anObject;
  CLArray *anArray;
  
  
  if ([self hasFieldNamed:@"urlTitle"] && ![[self urlTitle] length])
    [self createUrlTitleFromTitle];

  for (i = 0, j = [_removedCategories count]; i < j; i++) {
    aCat = [_removedCategories objectAtIndex:i];
    [self removeObject:aCat fromBothSidesOfRelationship:@"categories"];
  }

  anArray = [self files];
  for (i = [anArray count] - 1; i >= 0; i--) {
    anObject = [anArray objectAtIndex:i];
    if ([anObject willDelete])
      [self removeObject:anObject fromBothSidesOfRelationship:@"files"];
  }
  
  anArray = [self images];
  for (i = [anArray count] - 1; i >= 0; i--) {
    anObject = [anArray objectAtIndex:i];
    if ([anObject willDelete])
      [self removeObject:anObject fromBothSidesOfRelationship:@"images"];
  }
  
  [super willSaveToDatabase];
  return;
}

-(void) setPrimitiveValue:(id) anObject forKey:(CLString *) aKey
{
  if ([aKey isEqualToString:@"body"])
    [self setBody:anObject];
  else
    [super setPrimitiveValue:anObject forKey:aKey];
  return;
}

/* CLForm delegate methods */

-(BOOL) formShouldUseAutomaticPropertyList:(CLForm *) aForm
{
  if ([[[aForm attributes] objectForCaseInsensitiveString:@"id"]
	isEqualToString:@"theForm"])
    return YES;
  return NO;
}

-(void) formDidRestoreObject:(CLForm *) aForm fromDictionary:(CLDictionary *) aDict
{
  int i, j, k, l;
  CLArray *anArray, *categories;
  int oid;
  CLStandardContentCategory *aCat;


  if ([self hasFieldNamed:@"categories"]) {
    anArray = [aDict objectForKey:@"removedCategories"];
    categories = [self categories];
    for (i = 0, j = [anArray count]; i < j; i++) {
      oid = [[anArray objectAtIndex:i] intValue];
      for (k = 0, l = [categories count]; k < l; k++) {
	aCat = [categories objectAtIndex:k];
	if ([[aCat category] objectID] == oid) {
	  if (!_removedCategories)
	    _removedCategories = [[CLMutableArray alloc] init];
	  [_removedCategories addObject:aCat];
	  break;
	}
      }
    }
  }

  return;
}

-(CLString *) willDelete:(CLArray *) anArray
{
  CLMutableArray *mArray;
  CLString *aString;
  int i, j;
  id anObject;


  mArray = [[CLMutableArray alloc] init];
  for (i = 0, j = [anArray count]; i < j; i++) {
    anObject = [anArray objectAtIndex:i];
    if ([anObject willDelete])
      [mArray addObject:[CLNumber numberWithInt:[anObject objectID]]];
  }

  aString = [mArray componentsJoinedByString:@","];
  [mArray release];
  return aString;
}

-(CLString *) deleteFiles
{
  return [self willDelete:[self files]];
}

-(CLString *) deleteImages
{
  return [self willDelete:[self images]];
}

@end
