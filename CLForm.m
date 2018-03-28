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

#import "CLForm.h"
#import "CLInput.h"
#import "CLSelect.h"
#import "CLMutableArray.h"
#import "CLMutableString.h"
#import "CLMutableDictionary.h"
#import "CLManager.h"
#import "CLData.h"
#import "CLAutoreleasePool.h"
#import "CLGenericRecord.h"
#import "CLPage.h"
#import "CLPageTarget.h"
#import "CLOriginalFile.h"
#import "CLOriginalImage.h"
#import "CLAttribute.h"
#import "CLDecimalNumber.h"
#import "CLRuntime.h"
#import "CLEditingContext.h"
#import "CLRecordDefinition.h"
#import "CLStandardContent.h"
#import "CLDatetime.h"
#import "CLClassConstants.h"

#include <stdlib.h>
#include <unistd.h>
#include <string.h>

#define FIELD_PLIST	@"cl_plist"

#define hexval(c) ({int _c = c; toupper(_c) - '0' - (_c > '9' ? 7 : 0);})

/* FIXME - legacy C string based stuff */
#import "Header.h"
#include <ctype.h>
typedef struct ContentInfo {
  char *type;
  char *subtype;
  char **options;
} ContentInfo;

@implementation CLForm

-(id) initFromString:(CLString *) aString onPage:(CLPage *) aPage
{
  [super initFromString:aString onPage:aPage];
  return self;
}

-(void) dealloc
{
  [errors release];
  [super dealloc];
  return;
}

-(id) valueOfFieldNamed:(CLString *) aField
{
  return [[self fieldNamed:aField] value];
}

-(void) setValue:(id) aValue forFieldNamed:(CLString *) aField
{
  [[self fieldNamed:aField] setValue:aValue];
  return;
}

-(CLInput *) fieldNamed:(CLString *) aField withValue:(id) aValue inArray:(CLArray *) anArray
{
  int i, j;
  id anObject;
  

  for (i = 0, j = [anArray count]; i < j; i++) {
    anObject = [anArray objectAtIndex:i];
    if ([anObject isKindOfClass:CLInputClass] &&
	[[[anObject attributes] objectForCaseInsensitiveString:@"NAME"]
	  isEqualToString:aField] &&
	(!aValue || [[anObject value] isEqual:aValue]))
      return anObject;
    if ([anObject respondsTo:@selector(content)] &&
	[[anObject content] isKindOfClass:CLArrayClass] &&
	(anObject = [self fieldNamed:aField withValue:aValue inArray:[anObject content]]))
      return anObject;
  }
  
  return nil;
}

-(CLInput *) fieldNamed:(CLString *) field
{
  return [self fieldNamed:field withValue:nil inArray:content];
}

-(CLInput *) fieldNamed:(CLString *) field withValue:(id) aValue
{
  return [self fieldNamed:field withValue:aValue inArray:content];
}

-(CLArray *) fieldsNamed:(CLString *) field inArray:(CLArray *) anArray
{
  int i, j;
  id anObject;
  CLMutableArray *anArray2;
  

  anArray2 = [[CLMutableArray alloc] init];
  for (i = 0, j = [anArray count]; i < j; i++) {
    anObject = [anArray objectAtIndex:i];
    if ([anObject isKindOfClass:CLInputClass] &&
	[[[anObject attributes] objectForCaseInsensitiveString:@"NAME"]
	  isEqualToString:field])
      [anArray2 addObject:anObject];

    if ([anObject respondsTo:@selector(content)] &&
	[[anObject content] isKindOfClass:CLArrayClass] &&
	(anObject = [self fieldsNamed:field inArray:[anObject content]]))
      [anArray2 addObjectsFromArray:anObject];
  }

  if (![anArray2 count]) {
    [anArray2 release];
    anArray2 = nil;
  }
  
  return [anArray2 autorelease];
}

-(CLArray *) fieldsNamed:(CLString *) field
{
  return [self fieldsNamed:field inArray:content];
}

-(CLArray *) fieldNamesInArray:(CLArray *) anArray
{
  int i, j;
  CLMutableArray *mArray;
  CLString *aString;
  id anObject;


  mArray = [[CLMutableArray alloc] init];
  
  for (i = 0, j = [anArray count]; i < j; i++) {
    anObject = [anArray objectAtIndex:i];
    if ([anObject isKindOfClass:CLInputClass] &&
	(aString = [[anObject attributes] objectForCaseInsensitiveString:@"NAME"]))
      [mArray addObject:aString];

    if ([anObject respondsTo:@selector(content)] &&
	[[anObject content] isKindOfClass:CLArrayClass])
      [mArray addObjectsFromArray:[self fieldNamesInArray:[anObject content]]];
  }

  if (![mArray count]) {
    [mArray release];
    mArray = nil;
  }
  
  return [mArray autorelease];
}

-(CLArray *) fieldNames
{
  return [self fieldNamesInArray:content];
}

-(CLArray *) allFieldsInArray:(CLArray *) anArray
{
  int i, j;
  CLMutableArray *mArray;
  id anObject;


  mArray = [[CLMutableArray alloc] init];
  
  for (i = 0, j = [anArray count]; i < j; i++) {
    anObject = [anArray objectAtIndex:i];
    if ([anObject isKindOfClass:CLInputClass])
      [mArray addObject:anObject];

    if ([anObject respondsTo:@selector(content)] &&
	[[anObject content] isKindOfClass:CLArrayClass])
      [mArray addObjectsFromArray:[self allFieldsInArray:[anObject content]]];
  }

  if (![mArray count]) {
    [mArray release];
    mArray = nil;
  }
  
  return [mArray autorelease];
}

-(CLArray *) allFields
{
  return [self allFieldsInArray:content];
}

-(BOOL) removeFieldNamed:(CLString *) field fromArray:(CLMutableArray *) anArray
{
  int i, j;
  id anObject;
  

  if (!field)
    return NO;
  
  for (i = 0, j = [anArray count]; i < j; i++) {
    anObject = [anArray objectAtIndex:i];    
    if ([anObject isKindOfClass:CLInputClass] &&
	[[[anObject attributes] objectForCaseInsensitiveString:@"NAME"]
	  isEqualToString:field]) {
      [anArray removeObjectAtIndex:i];
      return YES;
    }
    if ([anObject respondsTo:@selector(content)] &&
	[[anObject content] isKindOfClass:CLMutableArrayClass] &&
	[self removeFieldNamed:field fromArray:[anObject content]])
      return YES;
  }
  
  return NO;
}

-(BOOL) removeFieldNamed:(CLString *) field
{
  return [self removeFieldNamed:field fromArray:content];
}

-(CLString *) query
{
  int i, j;
  CLInput *anObject;
  CLMutableString *mString;
  CLString *aString;
  

  mString = [[CLMutableString alloc] init];
  
  for (i = 0, j = [content count]; i < j; i++)
    if ([(anObject = [content objectAtIndex:i]) isKindOfClass:CLInputClass] &&
	(aString = [[anObject attributes] objectForCaseInsensitiveString:@"NAME"])) {
      if ([mString length])
	[mString appendString:@"&"];
      [mString appendString:[[aString description] stringByAddingPercentEscapes]];
      [mString appendString:@"="];
      if ((aString = [anObject value]))
	[mString appendString:[[aString description] stringByAddingPercentEscapes]];
    }

  if (![mString length]) {
    [mString release];
    mString = nil;
  }

  return [mString autorelease];
}
  
-(void) setQuery:(const char *) str
{
  char *q, *r, *s, *t, *v;
  const char *w;
  CLString *val;
  

  q = strdup(str);
  for (r = q; r && *r; ) {
    s = strchr(r, '=');
    *s++ = 0;
    if ((t = strchr(s, '&')))
      *t++ = 0;
    else
      t = s+strlen(s);
    w = [[[CLString stringWithUTF8String:r] stringByReplacingPercentEscapes] UTF8String];
    /* Netscape seems to like to stuff \r\n into the fields when the user
       pushes RETURN. It then also stuffs in a \n after that. Stupid. */
    for (v = s; *v; v++) {
      if (*v == '+')
	*v = ' ';
      else if (*v == '%') {
	*v = hexval(*(v+1)) << 4 | hexval(*(v+2));
	memmove(v+1, v+3, strlen(v+3) + 1);
      }
      else if (*v == '\r') {
	if (*(v+1) == '\n') {
	  if (*(v+2) == '\n')
	    memmove(v, v+2, strlen(v+2) + 1);
	  else
	    memmove(v, v+1, strlen(v+1) + 1);
	}
	else
	  *v = '\n';
      }
    }
    if (s && *s)
      val = [CLString stringWithUTF8String:s];
    else
      val = nil;
    [self addObject:[[[CLInput alloc] initWithTitle:[CLString stringWithUTF8String:w]
				      cols:0 rows:0
				      value:val type:CLTextInputType onPage:page]
		      autorelease]];
    r = t;
  }
  free(q);

  return;
}

-(void) selectRadioNamed:(CLString *) aName withValue:(id) aValue inArray:(CLArray *) anArray
{
  int i, j;
  id anObject;
  

  for (i = 0, j = [anArray count]; i < j; i++) {
    anObject = [anArray objectAtIndex:i];
    if ([anObject isKindOfClass:CLInputClass] &&
	[anObject type] == CLRadioInputType &&
	[[[anObject attributes] objectForCaseInsensitiveString:@"NAME"]
	  isEqualToString:aName] &&
	([anObject value] ||
	 ![[anObject attributes] objectForCaseInsensitiveString:@"CL_BINDING"])) {
      if ([[anObject value] isEqual:aValue])
	[anObject setChecked:YES];
      else
	[anObject setChecked:NO];
    }

    if ([anObject respondsTo:@selector(content)] &&
	[[anObject content] isKindOfClass:CLArrayClass])
      [self selectRadioNamed:aName withValue:aValue inArray:[anObject content]];
  }
  
  return;
}

-(void) selectRadioNamed:(CLString *) aName withValue:(id) aValue
{
  [self selectRadioNamed:aName withValue:aValue inArray:content];
  return;
}

-(CLForm *) pageForm
{
  CLString *aString;
  id anObject;


  if ((aString = [attributes objectForCaseInsensitiveString:@"ID"]) &&
      (anObject = [page objectWithID:aString]) &&
      [anObject isKindOfClass:CLFormClass])
    return anObject;

  return nil;
}

-(id) objectValueForBinding:(CLString *) aBinding found:(BOOL *) found
{
  CLRange aRange;
  CLString *aString;
  id anObject = nil;
  CLInput *aField;


  *found = NO;
  
  aRange = [aBinding rangeOfString:@"." options:0 range:CLMakeRange(0, [aBinding length])];
  if (!aRange.length)
    aString = aBinding;
  else
    aString = [aBinding substringToIndex:aRange.location];

  if (!(aField = [self fieldNamed:aString]))
    return [super objectValueForBinding:aBinding found:found];

  anObject = [aField value];
  *found = YES;

  if (aRange.length)
    anObject = [anObject objectValueForBinding:
			   [aBinding substringFromIndex:CLMaxRange(aRange)]
			 found:found];
  
  return anObject;
}

-(void) getContentInfo:(ContentInfo *) info for:(const char *) str
{
  const char *p, *q, *t;
  int is, st;
  char **r;
  char *s;
  

  p = str;
  for (q = p; *q && *q != '/' && *q != ';'; q++);
  t = q;
  while (isspace(*(t-1)))
    t--;
  if (!(info->type = realloc(info->type, t - p + 1)))
    [self error:@"Unable to allocate memory"];
  strncpy(info->type, p, t - p);
  info->type[t - p] = 0;

  if (*q != ';') {
    p = q+1;
    for (q = p; *q && *q != ';'; q++);
    t = q;
    while (isspace(*(t-1)))
      t--;
    if (!(info->subtype = realloc(info->subtype, t - p + 1)))
      [self error:@"Unable to allocate memory"];
    strncpy(info->subtype, p, t - p);
    info->subtype[t - p] = 0;
  }
  else {
    if (info->subtype)
      free(info->subtype);
    info->subtype = NULL;
  }

  for (r = info->options; r && *r; r++)
    free(*r);
  if (info->options)
    free(info->options);
  info->options = NULL;
  
  st = 0;
  while (*q) {
    p = q + 1;
    while (isspace(*p))
      p++;
    for (q = p, is = 0; *q && (is || *q != ';'); q++)
      if (*q == '"')
	is = !is;
    if (!(info->options = realloc(info->options, sizeof(char *) * (st + 2))))
      [self error:@"Unable to allocate memory"];
    if (!(info->options[st] = malloc(q - p + 1)))
      [self error:@"Unable to allocate memory"];
    strncpy(info->options[st], p, q - p);
    info->options[st][q - p] = 0;

    s = info->options[st];
    while (isspace(s[strlen(s) - 1]))
      s[strlen(s)-1] = 0;
    
    if ((s = strchr(info->options[st], '=')) && *(s+1) == '"') {
      memmove(s+1, s+2, strlen(s+2)+1);
      s[strlen(s) - 1] = 0;
    }
    st++;
    info->options[st] = NULL;
  }

  return;
}

-(void) getContentDisposition:(ContentInfo *) info for:(const char *) str
{
  const char *p, *q;
  int is, st;
  char **r;
  char *s;
  

  p = str;
  for (q = p; *q && *q != ';'; q++);
  if (!(info->type = realloc(info->type, q - p + 1)))
    [self error:@"Unable to allocate memory"];
  strncpy(info->type, p, q - p);
  info->type[q - p] = 0;

  for (r = info->options; r && *r; r++)
    free(*r);
  if (info->options)
    free(info->options);
  info->options = NULL;
  
  st = 0;
  while (*q) {
    p = q + 1;
    while (isspace(*p))
      p++;
    for (q = p, is = 0; *q && (is || *q != ';'); q++)
      if (*q == '"')
	is = !is;
    if (!(info->options = realloc(info->options, sizeof(char *) * (st + 2))))
      [self error:@"Unable to allocate memory"];
    if (!(info->options[st] = malloc(q - p + 1)))
      [self error:@"Unable to allocate memory"];
    strncpy(info->options[st], p, q - p);
    info->options[st][q - p] = 0;

    s = info->options[st];
    while (isspace(s[strlen(s) - 1]))
      s[strlen(s)-1] = 0;
    
    if ((s = strchr(info->options[st], '=')) && *(s+1) == '"') {
      strcpy(s+1, s+2);
      s[strlen(s) - 1] = 0;
    }
    st++;
    info->options[st] = NULL;
  }

  return;
}

-(void) freeContentInfo:(ContentInfo *) info
{
  char **r;


  if (info->type)
    free(info->type);
  info->type = NULL;
  if (info->subtype)
    free(info->subtype);
  info->subtype = NULL;
  for (r = info->options; r && *r; r++)
    free(*r);
  if (info->options)
    free(info->options);
  info->options = NULL;
  
  return;
}

-(const char *) getOption:(char **) options named:(const char *) str
{
  char **r;
  const char *p;
  
  
  for (r = options; r && *r && (strncasecmp(*r, str, strlen(str)) || ((*r)[strlen(str)] != '=')); r++);
  if (!r || !*r)
    return NULL;

  p = *r + strlen(str) + 1;
  
  return p;
}

-(const char *) seek:(const char *) str length:(int) len to:(const char *) pos
{
  int plen = strlen(pos);


  while (len) {
    if (*str == '-' && *(str+1) == '-' && !strncmp(str+2, pos, plen)) {
      if ((len - plen - 2 >= 0 && *(str+2+plen) == '\n') ||
	  (len - plen - 3 >= 0 && *(str+2+plen) == '\r' && *(str+3+plen) == '\n'))
	break;
      if (!strncmp(str+2+plen, "--", 2) &&
	  (len - plen - 4 == 0 ||
	   (len - plen - 5 >= 0 && *(str+4+plen) == '\n') ||
	   (len - plen - 6 >= 0 && *(str+4+plen) == '\r' && *(str+5+plen) == '\n')))
	break;
    }
    str++;
    len--;
  }

  return str;
}

-(void) handleMultipart:(const char *) body length:(unsigned int) length content:(ContentInfo *) info
{
  const char *p, *q, *s, *b;
  char *a;
  Header *aHeader;
  CLInput *aField;
  ContentInfo info2, disp2;
  char *body2;
  int len;
  char **r;
  CLMutableDictionary *aDict;
  

  if (!(b = [self getOption:info->options named:"boundary"]))
    return;

  aHeader = [(Header *)[Header alloc] initFromString:""];
  info2.type = info2.subtype = NULL;
  info2.options = NULL;
  disp2.type = disp2.subtype = NULL;
  disp2.options = NULL;

  if (!(body2 = malloc(length+1)))
    [self error:@"Unable to allocate memory"];
  memcpy(body2, body, length);
  body2[length] = 0;
  q = body2;
  len = length;
  while (q && *q) {
    q = [self seek:q length:len to:b];
    len = length - (q - body2);
    if (len) {
      if (len - strlen(b) - 2 > 0) {
	q += strlen(b);
	if (!strncmp(q, "--\r\n", 4))
	  break;
	q += 2;
	if (*q == '\n')
	  q++;
	else if (*q == '\r' && *(q+1) == '\n')
	  q += 2;
	s = q-1;
	while (*s && strncmp(s, "\r\n\r\n", 4)) /* FIXME - check for \n\n *and* \r\n\r\n */
	  s++;
	if (!(len - (s - q)))
	  s = q;
	[aHeader setHeaders:q length:s - q + 1];
	if ((p = [aHeader valueOf:"Content-Type"]))
	  [self getContentInfo:&info2 for:p];
	else {
	  [self freeContentInfo:&info2];
	  info2.type = strdup("Text");
	  info2.subtype = strdup("Plain");
	}
	if ((p = [aHeader valueOf:"Content-Disposition"]))
	  [self getContentInfo:&disp2 for:p];
	else {
	  [self freeContentInfo:&disp2];
	  disp2.type = disp2.subtype = NULL;
	  disp2.options = NULL;
	}	  

	q = s + 4; /* FIXME - could be \n\n, not just \r\n\r\n */
	if (q >= body2 + length)
	  break;
	
	aField = [[CLInput alloc] init];
	aDict = [aField attributes];
	for (r = disp2.options; r && *r; r++) {
	  a = strchr(*r, '=');
	  *a = 0;
	  a++;
	  [aDict setObject:[CLString stringWithUTF8String:a]
		 forCaseInsensitiveString:[CLString stringWithUTF8String:*r]];
	}

	s = [self seek:q length:len to:b];
	s -= 2; /* FIXME - could be \n, not just \r\n */
	if (!(a = malloc((s - q) + 1)))
	  [self error:@"Unable to allocate memory"];
	memcpy(a, q, s - q);
	a[s-q] = 0;

	if (s-q) {
	  CLString *aString;

	  
	  if ((aString = [aDict objectForCaseInsensitiveString:@"filename"])) {
	    CLOriginalFile *aFile;
	    CLData *aData;


	    aData = [CLData dataWithBytes:a length:s-q];
	    aFile = [CLOriginalFile fileFromData:aData table:nil];
	    if ([aFile isImage] && [CLEditingContext
				     tableForClass:[CLOriginalImage imageClass]])
	      aFile = [[CLOriginalImage imageClass] imageFromData:aData table:nil];

	    /* Strip off full path that IE6 puts in */
	    aString = [[aString componentsSeparatedByString:@"\\"] lastObject];
	    aString = [aString lastPathComponent];
	    
	    [aFile setFilename:aString];
	    [aField setValue:aFile];
	  }
	  else
	    [aField setValue:[CLString stringWithBytes:a length:s - q
				       encoding:CLUTF8StringEncoding]];
	}
	free(a);
	
	[self addObject:aField];
	[aField release];
	
	q = s;
	len = length - (body2 - q);
      }
      else
	break;
    }

    while (*q && *q != '\n')
      q++;
    if (*q)
      q++;
  }

  [aHeader release];
  [self freeContentInfo:&info2];
  [self freeContentInfo:&disp2];

  free(body2);
  
  return;
}

-(void) readMultipart:(const char *) formData
{
  ContentInfo info;
  char *body;
  int length;
  const char *p;


  info.type = info.subtype = NULL;
  info.options = NULL;
  [self getContentInfo:&info for:formData];
  p = getenv("CONTENT_LENGTH");
  length = atoi(p);
  if (!(body = malloc(length)))
    [self error:@"Unable to allocate memory"];
  fread(body, length, 1, stdin);
  [self handleMultipart:body length:length content:&info];
  free(body);
  
  return;
}

-(CLAttributeType) databaseTypeOfBinding:(CLString *) aBinding forObject:(id) anObject
{
  CLString *aString;
  CLRange aRange;
  CLRecordDefinition *recordDef;
  

  if (!anObject)
    return 0;
  
  aRange = [aBinding rangeOfString:@"." options:0 range:CLMakeRange(0, [aBinding length])];
  if (aRange.length) {
    aString = [aBinding substringToIndex:aRange.location];
    anObject = [anObject objectValueForBinding:aString];
    return [self databaseTypeOfBinding:[aBinding substringFromIndex:CLMaxRange(aRange)]
		 forObject:anObject];
  }

  if (![CLEditingContext tableForClass:[anObject class]] ||
      !(recordDef = [CLEditingContext recordDefinitionForClass:[anObject class]]))
    return 0;

  return [[[recordDef fields] objectForKey:aBinding] externalType];
}

-(BOOL) validateValue:(id *) aValue object:(id) anObject forBinding:(CLString *) aBinding
		error:(CLString **) errString field:(CLInput *) aField
{
  CLRange aRange;
  CLString *aString, *format;
  id anObject2;
  SEL aSel;
  BOOL valid = YES, success;
  IMP imp;
  CLAttributeType aType;


  aRange = [aBinding rangeOfString:@"." options:0 range:CLMakeRange(0, [aBinding length])];
  if (aRange.length) {
    aString = [aBinding substringToIndex:aRange.location];
    anObject2 = [anObject objectValueForBinding:aString];
    valid = [self validateValue:aValue object:anObject2
		     forBinding:[aBinding substringFromIndex:CLMaxRange(aRange)]
			  error:errString field:aField];
  }
  else {
    if (*aValue) {
      aType = [self databaseTypeOfBinding:aBinding forObject:anObject];
      if ((format = [[aField attributes] objectForCaseInsensitiveString:@"CL_FORMAT"])) {
	format = [self expandBinding:format success:&success];
	if ([format isKindOfClass:[CLArray class]])
	  format = [((CLArray *) format) componentsJoinedByString:@" "];
      }
      switch (aType) {
      case CLDatetimeAttributeType:
	if (!format)
	  format = @"%Y-%m-%d %H:%M:%S %z";
	*aValue = [CLDatetime dateWithString:[(*aValue) description] format:format];
	break;

      case CLIntAttributeType:
      case CLMoneyAttributeType:
      case CLNumericAttributeType:
	if (!format)
	  format = @"0.00";
	*aValue = [CLDecimalNumber decimalNumberWithString:[(*aValue) description]];
	break;
      
      default:
	break;
      }
    }
    
    aString = [CLString stringWithFormat:@"validate%@:error:",
			[aBinding upperCamelCaseString]];
    aSel = sel_getUid([aString UTF8String]);
    if ((imp = [anObject methodFor:aSel]))
      valid = ((BOOL (*) (id,SEL,id*,CLString**)) imp)(anObject, aSel, aValue, errString);
  }

  return valid;
}

-(BOOL) bindingIsPrimaryKey:(CLString *) aBinding forObject:(id) anObject
{
  CLRecordDefinition *recordDef;
  CLRange aRange;
  CLString *aString;


  recordDef = [CLEditingContext recordDefinitionForClass:[anObject class]];
  if (!recordDef)
    return NO;

  aRange = [aBinding rangeOfString:@"." options:0 range:CLMakeRange(0, [aBinding length])];
  if (!aRange.length)
    aString = aBinding;
  else
    aString = [aBinding substringToIndex:aRange.location];

  if ([recordDef isPrimaryKey:aString])
    return YES;

  if (aRange.length && (anObject = [anObject objectValueForBinding:aString]))
    return [self bindingIsPrimaryKey:[aBinding substringFromIndex:CLMaxRange(aRange)]
			   forObject:anObject];

  return NO;
}

-(CLArray *) setBindings:(CLArray *) anArray error:(int *) err
{
  int i, j, k, l;
  id aField, anObject, aValue;
  CLMutableArray *updated;
  CLString *aBinding, *fName, *errString;
  

  updated = [[CLMutableArray alloc] init];
  for (i = 0, j = [anArray count]; i < j; i++) {
    aField = [anArray objectAtIndex:i];
    if ([aField isKindOfClass:CLInputClass] &&
	(fName = [[aField attributes] objectForCaseInsensitiveString:@"NAME"])) {
      if ([aField isKindOfClass:CLSelectClass])
	aBinding = [[aField attributes] objectForCaseInsensitiveString:@"CL_SELECTED"];
      else {
	switch ([aField type]) {
	case CLCheckboxInputType:
	case CLRadioInputType:
	  if ((aBinding = [[aField attributes]
			    objectForCaseInsensitiveString:@"CL_CHECKED"]) &&
	      ![aBinding isKindOfClass:CLStringClass])
	    aBinding = nil;
	  break;

	default:
	  aBinding = [[aField attributes] objectForCaseInsensitiveString:@"CL_BINDING"];
	  break;
	}
      }
      
      if ([aBinding length] > 1 && (anObject = [aField datasource])) {
	aValue = [self valueOfFieldNamed:fName];
	/* All bindings must begin with = and it doesn't make sense to
	   use constants here, so start with second character in
	   aBinding */
	aBinding = [aBinding substringFromIndex:1];
	if ([self validateValue:&aValue object:anObject forBinding:aBinding
			  error:&errString field:aField]) {
	  if (![self bindingIsPrimaryKey:aBinding forObject:anObject]) {
	    if (aValue || ![[anObject objectValueForBinding:aBinding]
			     isKindOfClass:CLOriginalFileClass])
	      [anObject setObjectValue:aValue forBinding:aBinding];
	    if (anObject && ![updated containsObject:anObject])
	      [updated addObject:anObject];
	  }
	}
	else {
	  [[[self pageForm] fieldNamed:fName] setErrorString:errString ignoreBinding:YES];
	  [errors setObject:errString forKey:fName];
	  *err = *err + 1;
	}
      }
    }

    if ([aField respondsTo:@selector(content)] &&
	[[aField content] isKindOfClass:CLArrayClass] &&
	(aField = [self setBindings:[aField content] error:err])) {
      for (k = 0, l = [aField count]; k < l; k++)
	if (![updated containsObject:(anObject = [aField objectAtIndex:k])])
	  [updated addObject:anObject];
    }
  }

  if (![updated count]) {
    [updated release];
    updated = nil;
  }
  
  return [updated autorelease];
}

-(CLControl *) prepareVaction:(CLForm *) aForm
{
  CLString *aString;
  CLControl *aControl;
  CLRange aRange;
  BOOL success;


  aControl = [[CLControl alloc] init];
  
  if ((aString = [[aForm attributes] objectForCaseInsensitiveString:@"CL_VTARGET"]))
    [aControl setTarget:[self expandBinding:aString success:&success]];

  if ((aString = [[aForm attributes] objectForCaseInsensitiveString:@"CL_VACTION"])) {
    aRange = [aString rangeOfString:@":"];
    if (!aRange.length)
      aString = [aString stringByAppendingString:@":"];
    else if (aRange.location < [aString length] - 1) {
      [aControl setTarget:[self expandBinding:[aString substringToIndex:aRange.location]
				      success:&success]];
      aString = [aString substringFromIndex:CLMaxRange(aRange)];
    if ([aString length] && [aString characterAtIndex:[aString length]-1] != ':')
      aString = [aString stringByAppendingString:@":"];
    }
    
    [aControl setAction:sel_getUid([aString UTF8String])];
    if (![aControl target])
      [aControl setTarget:[aForm target]];
    if (![aControl target])
      [aControl setTarget:[page owner]];
    return aControl;
  }

  if ((aString = [[aForm attributes] objectForCaseInsensitiveString:@"CL_VPAGE"])) {
    [aControl setTarget:[[[CLPageTarget alloc] initFromPath:
					[self expandBinding:aString success:&success]]
			  autorelease]];
    [aControl setAction:@selector(showPage:)];
    return aControl;
  }

  [aControl release];
  return nil;
}
  
-(CLControl *) setBindings
{
  CLForm *aForm;
  CLString *aString;
  CLArray *anArray;
  CLControl *aControl = nil;
  int i, j;
  int err = 0;


  if ((aString = [attributes objectForCaseInsensitiveString:@"ID"]) &&
      (aForm = [page objectWithID:aString]) &&
      [aForm isKindOfClass:CLFormClass]) {
    errors = [[CLMutableDictionary alloc] init];
    
    anArray = [self setBindings:[aForm content] error:&err];
    /* In theory if the action is a "magic" method then the target
       won't respond to it and we should automatically save to the
       database. */
    wasError = !!err;
    if (!err && ![target respondsTo:action]) {
      for (i = 0, j = [anArray count]; i < j; i++) {
	[anArray objectAtIndex:i];
	/* FIXME - use context of whatever objects we changed */
	[CLDefaultContext saveChanges];
      }

      aControl = [self prepareVaction:aForm];
    }
  }

  return aControl;
}

-(BOOL) wasError
{
  return wasError;
}

-(CLDictionary *) errors
{
  return errors;
}

-(void) readData
{
  const char *p;
  CLMutableString *mString;
  CLArray *keys;
  int i, j;
  CLString *aKey;
  char *q;


  if ((p = getenv("REQUEST_METHOD")) && !strcasecmp(p, "GET")) {
    mString = [[CLMutableString alloc] init];
    keys = [CLQuery allKeys];
    for (i = 0, j = [keys count]; i < j; i++) {
      aKey = [keys objectAtIndex:i];
      if (![aKey hasPrefix:@"CLurl"]) {
	if ([mString length])
	  [mString appendString:@"&"];
	[mString appendString:[[aKey description] stringByAddingPercentEscapes]];
	[mString appendString:@"="];
	[mString appendString:[[[CLQuery objectForKey:aKey] description]
				stringByAddingPercentEscapes]];
	[CLQuery removeObjectForKey:aKey];
      }
    }
    [self setQuery:[mString UTF8String]];
    [mString release];
  }
  else if ((p = getenv("CONTENT_TYPE")) && !strncasecmp(p, "multipart/form-data", 19))
    [self readMultipart:p];
  else if ((p = getenv("CONTENT_LENGTH"))) {
    i = atoi(p);
    if (!(q = malloc(i+1)))
      [self error:@"Unable to allocate memory"];
    fread(q, i, 1, stdin);
    q[i] = 0;
    [self setQuery:q];
    free(q);
  }

  return;
}

-(void) restoreObject:(id) anObject
{
  CLString *aString;
  CLDictionary *aDict;


  if ((aString = [self valueOfFieldNamed:FIELD_PLIST]) &&
      [anObject respondsTo:@selector(setFieldsFromDictionary:updateChanged:)] &&
      [anObject respondsTo:@selector(formShouldUseAutomaticPropertyList:)] &&
      [anObject formShouldUseAutomaticPropertyList:self]) {
    aDict = [aString decodePropertyList];
    [anObject setFieldsFromDictionary:aDict updateChanged:NO];
    if ([anObject respondsTo:@selector(formDidRestoreObject:fromDictionary:)])
      [anObject formDidRestoreObject:self fromDictionary:aDict];
  }

  return;
}  
  
-(BOOL) doAction:(CLControl *) aControl
{
  BOOL perform;


  if (!(perform = [[CLManager manager] checkPermission:aControl]) &&
      [CLDelegate respondsTo:@selector(accessDenied:)])
    [CLDelegate accessDenied:aControl];

  if (perform && [[page owner] respondsTo:@selector(controlShouldPerform:)])
    perform = [[page owner] controlShouldPerform:aControl];
  else if (perform && [CLDelegate respondsTo:@selector(controlShouldPerform:)])
    perform = [CLDelegate controlShouldPerform:aControl];
  if (perform) {
    if ([[aControl target] isKindOfClass:CLPageTargetClass])
      CLRedirectBrowserToPage([[aControl target] path], YES);
    else {
      [[aControl target] perform:[aControl action] with:self];
      [page display];
    }
  }

  return perform;
}

-(BOOL) doVaction
{
  CLForm *aForm;
  CLString *aString;
  CLControl *aControl;


  if ((aString = [attributes objectForCaseInsensitiveString:@"ID"]) &&
      (aForm = [page objectWithID:aString]) &&
      [aForm isKindOfClass:CLFormClass] &&  
      (aControl = [self prepareVaction:aForm]))
    return [self doAction:aControl];

  return NO;
}

-(void) performAction
{
  CLStream *stream;
  CLAutoreleasePool *pool;
  CLControl *aControl;


  pool = [[CLAutoreleasePool alloc] init];
  [self readData];
  
  {
    CLString *aString;
    CLData *aData;


    if ((aString = [CLQuery objectForKey:CL_URLDATA])) {
      aData = [aString decodeBase64];
      stream = [CLStream openWithData:aData mode:CLReadOnly];
      [self readURL:stream];
      [stream close];
    }
  }

  /* FIXME - might need to updateBindings of the page in order to get
     all the autonumbered fields available */
  if (!(aControl = [self setBindings]))
    aControl = self;
  
  [[self pageForm] copyValuesFrom:self];
  [self doAction:aControl];
  
  [pool release];

  return;
}
  
-(void) copyValuesFrom:(id) aForm array:(CLArray *) anArray
{
  int i, j;
  id anObject, aValue;
  CLString *aString;
  

  for (i = 0, j = [anArray count]; i < j; i++) {
    anObject = [anArray objectAtIndex:i];
    if ([anObject isKindOfClass:CLInputClass] &&
	(aString = [[anObject attributes] objectForCaseInsensitiveString:@"NAME"])) {
      aValue = nil;
      if ([aForm respondsTo:@selector(objectForCaseInsensitiveString:)])
	aValue = [aForm objectForCaseInsensitiveString:aString];
      else if ([aForm respondsTo:@selector(valueOfFieldNamed:)])
	aValue = [aForm valueOfFieldNamed:aString];
      
      if (aValue) {
	if ([anObject type] == CLRadioInputType)
	  [self selectRadioNamed:aString withValue:aValue];
	else if ([anObject type] == CLCheckboxInputType)
	  [[self fieldNamed:aString] setChecked:YES];
	else if ([anObject isKindOfClass:CLSelectClass])
	  [anObject selectOptionWithValue:aValue];
	else
	  [self setValue:aValue forFieldNamed:aString];
      }
    }
    else if ([anObject respondsTo:@selector(content)] &&
	     [[anObject content] isKindOfClass:CLArrayClass])
      [self copyValuesFrom:aForm array:[anObject content]];
  }
  
  return;
}

-(void) copyValuesFrom:(id) aForm
{
  [self copyValuesFrom:aForm array:content];
  return;
}

-(void) writeAttributes:(CLStream *) stream ignore:(CLMutableArray *) ignore
{
  if (!ignore)
    ignore = [CLMutableArray array];
  [ignore addObjects:@"CL_CHECKED", @"CL_SELECTED", @"CL_BINDING",
	  @"CL_VTARGET", @"CL_VACTION", @"CL_VPAGE", nil];
  
  [super writeAttributes:stream ignore:ignore];
  return;
}

-(CLDictionary *) dictionary
{
  CLArray *anArray, *anArray2;
  CLMutableDictionary *mDict;
  int i, j, k, l;
  CLString *aKey;
  CLMutableArray *mArray;
  id anObject;
  CLInput *aField;


  mDict = [[CLMutableDictionary alloc] init];
  anArray = [self fieldNames];
  for (i = 0, j = [anArray count]; i < j; i++) {
    aKey = [anArray objectAtIndex:i];
    anArray2 = [self fieldsNamed:aKey];
    if ([anArray2 count] > 1) {
      mArray = [[CLMutableArray alloc] init];
      for (k = 0, l = [anArray2 count]; k < l; k++) {
	aField = [anArray2 objectAtIndex:k];
	if ((anObject = [aField value]))
	  [mArray addObject:anObject];
      }
      if ([mArray count])
	[mDict setObject:mArray forKey:aKey];
      [mArray release];
    }
    else if ((anObject = [[anArray2 objectAtIndex:0] value]))
      [mDict setObject:anObject forKey:aKey];
  }

  return [mDict autorelease];
}

-(CLString *) generateURL:(BOOL) get
{
  CLStream *stream, *stream2;
  CLString *aURL = nil;
  CLData *aData;


  stream = [CLStream openMemoryForWriting];
  stream2 = [CLStream openMemoryForWriting];
  [self writeURL:stream2];
  aData = [stream2 data];
  CLWriteURLForGet(stream, self, aData, localQuery, get);
  [CLQuery removeObjectForKey:CL_URLSEL];
  [stream2 close];
  /* FIXME - we should be using nocopy to move the stream buffer into the string */
  aData = [stream data];
  aURL = [CLString stringWithData:aData encoding:CLUTF8StringEncoding];
  [stream close];

  aURL = [[self class] rewriteURL:[aURL entityDecodedString]];

  return aURL;
}

-(void) writeHTML:(CLStream *) stream
{
  int i, j;
  BOOL get = NO;
  CLArray *keys;
  CLString *aKey;
  CLString *aString;
  

  if (![self isVisible])
    return;

  if ([self isEnabled]) {
    [stream writeString:@"<FORM" usingEncoding:CLUTF8StringEncoding];
    if (target && action) {
      if (!(aString = [attributes objectForCaseInsensitiveString:@"METHOD"])
	  || [aString caseInsensitiveCompare:@"GET"])
	[attributes setObject:@"POST" forCaseInsensitiveString:@"METHOD"];
      else
	get = YES;
	
      [stream writeFormat:@" ACTION=\"%@\"" usingEncoding:CLUTF8StringEncoding,
	[self generateURL:get]];
    }

    [self writeAttributes:stream ignore:nil];
    [stream writeString:@">" usingEncoding:CLUTF8StringEncoding];

    if (get) {
      keys = [CLQuery allKeys];
      for (i = 0, j = [keys count]; i < j; i++) {
	aKey = [keys objectAtIndex:i];
	CLPrintf(stream, @"<INPUT TYPE=hidden NAME=%@ VALUE=\"%@\">", aKey,
		 [[[CLQuery objectForKey:aKey] description] stringByAddingPercentEscapes]);
	if ([aKey hasPrefix:@"url"])
	  [CLQuery removeObjectForKey:aKey];
      }

      keys = [localQuery allKeys];
      for (i = 0, j = [keys count]; i < j; i++) {
	aKey = [keys objectAtIndex:i];
	CLPrintf(stream, @"<INPUT TYPE=hidden NAME=%@ VALUE=\"%@\">", aKey,
		 [[[localQuery objectForKey:aKey] description]
		   stringByAddingPercentEscapes]);
      }
    }
  }

  CLWriteHTMLObject(stream, content);

  {
    id anObject;
    CLInput *aField;


    anObject = [self datasource];
    if ([anObject respondsTo:@selector(propertyList)] &&
	[anObject respondsTo:@selector(formShouldUseAutomaticPropertyList:)] &&
	[anObject formShouldUseAutomaticPropertyList:self]) {
      aField = [[CLInput alloc] initWithTitle:FIELD_PLIST cols:0 rows:0
			     value:[anObject propertyList]
			     type:CLHiddenInputType onPage:nil];
      CLWriteHTMLObject(stream, aField);
      [aField release];
    }
  }  
  
  if ([self isEnabled])
    CLPrintf(stream, @"</FORM>");

  return;
}

@end
