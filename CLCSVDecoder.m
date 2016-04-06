/* Copyright 2013-2016 by
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

#import "CLCSVDecoder.h"
#import "CLMutableString.h"
#import "CLMutableArray.h"
#import "CLStringFunctions.h"
#import "CLCharacterSet.h"

@interface CLMutableString (CLCSVDecoding)
-(void) dequoteCSV;
@end

@implementation CLMutableString (CLCSVDecoding)

-(void) dequoteCSV
{
  unistr *ustr;
  int i;


  ustr = CLStringToUnistr(self);
  wmemmove(ustr->str, ustr->str + 1, ustr->len - 1);
  ustr->len--;
  for (i = 0; i < ustr->len - 1; i++)
    if (ustr->str[i] == '"' && ustr->str[i+1] == '"') {
      wmemmove(&ustr->str[i], &ustr->str[i+1], ustr->len - i - 1);
      ustr->len--;
    }

  if (ustr->len && ustr->str[ustr->len-1] == '"')
    ustr->len--;
  
  return;
}

@end

@implementation CLCSVDecoder

-(id) init
{
  return [self initWithString:nil fieldSeparator:nil];
}

-(id) initWithString:(CLString *) aString fieldSeparator:(CLCharacterSet *) aSet
{
  [super init];
  csvString = [aString retain];
  fieldSep = [aSet retain];
  position = 0;
  record = [[CLMutableArray alloc] init];
  return self;
}
  
-(void) dealloc
{
  [csvString release];
  [fieldSep release];
  [record release];
  [super dealloc];
  return;
}

-(void) addFieldWithCharacters:(unichar *) str length:(int) len
{
  CLMutableString *mString;

  
  mString = [[CLMutableString alloc] initWithCharacters:str length:len];
  if (len && str[0] == '"')
    [mString dequoteCSV];
  [record addObject:mString];
  [mString release];
  return;
}
  
-(CLArray *) decodeNextRow
{
  CLUInteger i, j;
  BOOL inString;
  unistr *csvStr;
  BOOL foundField = NO;


  csvStr = CLStringToUnistr(csvString);

  [record removeAllObjects];
  inString = NO;
  for (i = j = position; i < csvStr->len; i++) {
    if (csvStr->str[i] == '"') {
      if (inString && i+1 < csvStr->len && csvStr->str[i+1] == '"')
	i++;
      else
	inString = !inString;
    }
    
    if (!inString) {
      if ([fieldSep characterIsMember:csvStr->str[i]]) {
	[self addFieldWithCharacters:&csvStr->str[j] length:i-j];
	j = i+1;
	foundField = YES;
      }
      else if (csvStr->str[i] == '\r' || csvStr->str[i] == '\n') {
	if (csvStr->str[i] != '\n' || !i || csvStr->str[i-1] != '\r') {
	  [self addFieldWithCharacters:&csvStr->str[j] length:i-j];
	  foundField = YES;
	}
	while (csvStr->str[i] == '\n' || csvStr->str[i] == '\r')
	  i++;
	j = i;
	break;
      }
    }
  }

  if (j < i) {
    [self addFieldWithCharacters:&csvStr->str[j] length:i-j];
    j = i+1;
    foundField = YES;
  }
  else if (i && i == csvStr->len && [fieldSep characterIsMember:csvStr->str[i-1]]) {
    [record addObject:@""];
    j = i + 1;
    foundField = YES;
  }
  position = j;

  if (!foundField)
    return nil;
  
  return record;
}

@end
