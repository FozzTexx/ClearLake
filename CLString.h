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

#ifndef _CLSTRING_H
#define _CLSTRING_H

#import <ClearLake/CLObject.h>
#import <ClearLake/CLRange.h>

@class CLData, CLCharacterSet, CLArray;

#include <wchar.h>
#include <stdarg.h>

typedef wchar_t unichar;

typedef enum {
  CLASCIIStringEncoding = 1,
  CLNEXTSTEPStringEncoding,
  CLJapaneseEUCStringEncoding,
  CLUTF8StringEncoding,
  CLISOLatin1StringEncoding,
  CLISOLatin2StringEncoding,
  CLISOLatin7StringEncoding,
  CLShiftJISStringEncoding,
  CLUnicodeStringEncoding,
  CLWindowsCP1250StringEncoding,
  CLWindowsCP1251StringEncoding,
  CLWindowsCP1252StringEncoding,
  CLWindowsCP1253StringEncoding,
  CLWindowsCP1254StringEncoding,
  CLISO2022JPStringEncoding,
  CLMacOSRomanStringEncoding,
  CLUTF16BigEndianStringEncoding,
  CLUTF16LittleEndianStringEncoding,
  CLUTF32StringEncoding,
  CLUTF32BigEndianStringEncoding,
  CLUTF32LittleEndianStringEncoding,
  CLKOI8StringEncoding,
  CLProprietaryStringEncoding
} CLStringEncoding;

typedef enum {
  CLCaseInsensitiveSearch = 1,
  CLLiteralSearch = 2,
  CLBackwardsSearch = 4,
  CLAnchoredSearch = 8,
  CLNumericSearch = 16,
  CLDiacriticInsensitiveSearch = 32,
  CLWidthInsensitiveSearch = 64,
  CLForcedOrderingSearch = 128,
  CLInvertedSearch = 256
} CLStringCompareOptions;

@interface CLString:CLObject <CLCopying, CLMutableCopying, CLArchiving, CLPropertyList>
{
  void *data;
  CLUInteger len;
}

-(id) initWithBytes:(const char *) bytes length:(CLUInteger) length
	   encoding:(CLStringEncoding) encoding;
-(id) initWithBytesNoCopy:(const char *) bytes length:(CLUInteger) length
		 encoding:(CLStringEncoding) encoding;
-(void) dealloc;

/* Basic functionality */
-(CLUInteger) length;
-(unichar) characterAtIndex:(CLUInteger) index;
-(void) getCharacters:(unichar *) buffer range:(CLRange) aRange;

/* Using strings */
-(const char *) UTF8String;
-(CLString *) description;

/* Identifying strings */
-(CLUInteger) hash;

@end

@interface CLString (CLStringCreation)
+(id) string;
+(id) stringWithCharacters:(const unichar *) chars length:(CLUInteger) length;
+(id) stringWithUTF8String:(const char *) bytes;
+(id) stringWithString:(CLString *) aString;
+(id) stringWithBytes:(const char *) bytes length:(CLUInteger) length
	     encoding:(CLStringEncoding) encoding;
+(id) stringWithBytesNoCopy:(const char *) bytes length:(CLUInteger) length
	     encoding:(CLStringEncoding) encoding;
+(id) stringWithData:(CLData *) aData encoding:(CLStringEncoding) encoding;
+(id) stringWithContentsOfFile:(CLString *) path encoding:(CLStringEncoding) enc;

-(id) initWithCString:(const char *) cString encoding:(CLStringEncoding) encoding;
-(id) initWithUTF8String:(const char *) bytes;
-(id) initWithCharacters:(const unichar *) characters length:(CLUInteger) length;
-(id) initWithString:(CLString *) aString;
-(id) initWithData:(CLData *) aData encoding:(CLStringEncoding) encoding;
-(id) initWithContentsOfFile:(CLString *) path encoding:(CLStringEncoding) enc;
@end

@interface CLString (CLStringComparison)
-(CLComparisonResult) compare:(CLString *) aString;
-(CLComparisonResult) compare:(CLString *) aString options:(CLStringCompareOptions) mask;
-(CLComparisonResult) compare:(CLString *) aString options:(CLStringCompareOptions) mask
			range:(CLRange) range;
-(CLComparisonResult) caseInsensitiveCompare:(CLString *) aString;
-(BOOL) hasPrefix:(CLString *) prefix;
-(BOOL) hasSuffix:(CLString *) suffix;
-(CLRange) rangeOfString:(CLString *) aString;
-(CLRange) rangeOfString:(CLString *) aString options:(CLStringCompareOptions) mask;
-(CLRange) rangeOfString:(CLString *) aString options:(CLStringCompareOptions) mask
		   range:(CLRange) range;
-(CLRange) rangeOfCharacterFromSet:(CLCharacterSet *) aSet;
-(CLRange) rangeOfCharacterFromSet:(CLCharacterSet *) aSet
			   options:(CLStringCompareOptions) mask range:(CLRange) aRange;
-(CLRange) rangeOfCharacterNotFromSet:(CLCharacterSet *) aSet
			      options:(CLStringCompareOptions) mask range:(CLRange) aRange;
-(BOOL) isEqual:(id) anObject;
-(BOOL) isEqualToString:(CLString *) aString;
-(BOOL) isEqualToCaseInsensitiveString:(CLString *) aString;

-(CLRange) rangeOfTag:(CLString *) aTag inRange:(CLRange) aRange;
-(CLRange) rangeOfTag:(CLString *) aTag inRange:(CLRange) aRange allowCDATA:(BOOL) cdataFlag;
-(BOOL) getRangeOfBlock:(CLString *) startTag end:(CLString *) endTag
	     outerRange:(CLRange *) outerRange innerRange:(CLRange *) innerRange
		inRange:(CLRange) aRange;
-(BOOL) getRangeOfBlock:(CLString *) startTag end:(CLString *) endTag
	     outerRange:(CLRange *) outerRange innerRange:(CLRange *) innerRange
		inRange:(CLRange) aRange allowCDATA:(BOOL) cdataFlag;
@end

@interface CLString (CLStringPaths)
+(CLString *) pathWithComponents:(CLArray *) components;

-(BOOL) isAbsolutePath;
-(BOOL) hasPathPrefix:(CLString *) prefix;
-(CLString *) stringByAppendingPathComponent:(CLString *) aString;
-(CLString *) stringByAppendingPathExtension:(CLString *) ext;
-(CLString *) stringByDeletingLastPathComponent;
-(CLString *) stringByDeletingPathExtension;
-(CLString *) stringByDeletingPathPrefix:(CLString *) aPrefix;
-(CLArray *) pathComponents;
-(CLString *) pathExtension;
-(CLString *) lastPathComponent;
@end

@interface CLString (CLStringEncodings)
-(CLData *) decodeBase64;
-(CLString *) entityEncodedString;
-(CLString *) xmlEntityEncodedString;
-(CLString *) entityDecodedString;
-(CLString *) stringByAddingPercentEscapes;
-(CLString *) stringByReplacingPercentEscapes;
-(id) decodePropertyList;
-(id) decodeJSON;
-(id) decodeXML;
-(CLArray *) decodeCSV;
-(CLArray *) decodeCSVUsingCharacterSet:(CLCharacterSet *) aSet;
-(CLData *) dataUsingEncoding:(CLStringEncoding) encoding;
-(CLData *) dataUsingEncoding:(CLStringEncoding) encoding allowLossyConversion:(BOOL) flag;
-(CLString *) htmlLineBreaks;
@end

@interface CLString (CLStringCombining)
-(CLString *) stringByAppendingString:(CLString *) aString;
@end

@interface CLString (CLStringDividing)
-(CLArray *) componentsSeparatedByCharactersInSet:(CLCharacterSet *) separator;
-(CLArray *) componentsSeparatedByString:(CLString *) separator;
-(CLString *) stringByTrimmingCharactersInSet:(CLCharacterSet *) set;
-(CLString *) stringByTrimmingWhitespaceAndNewlines;
-(CLString *) substringFromIndex:(CLUInteger) anIndex;
-(CLString *) substringToIndex:(CLUInteger) anIndex;
-(CLString *) substringWithRange:(CLRange) range;
@end

@interface CLString (CLStringReplacing)
-(CLString *) stringByReplacingOccurrencesOfString:(CLString *) target
					withString:(CLString *) replacement;
-(CLString *) stringByReplacingOccurrencesOfString:(CLString *) target
					withString:(CLString *) replacement
					   options:(CLStringCompareOptions) options
					     range:(CLRange) searchRange;
-(CLString *) stringByReplacingCharactersInRange:(CLRange) range
				      withString:(CLString *) replacement;
-(CLString *) propertyListString;
-(CLString *) reversePropertyListString;
-(CLString *) shellEscaped;
-(CLString *) shellEscapedIgnoreSpace;
@end

@interface CLString (CLStringNumeric)
-(BOOL) boolValue;
-(int) intValue;
-(long long) longLongValue;
-(unsigned long) unsignedLongValue;
-(unsigned long long) unsignedLongLongValue;
-(double) doubleValue;
@end

@interface CLString (CLStringCase)
-(CLString *) lowercaseString;
-(CLString *) uppercaseString;
-(CLString *) lowerCamelCaseString;
-(CLString *) upperCamelCaseString;
-(CLString *) underscore_case_string;
@end

@interface CLString (CLStringFormatting)
+(id) stringWithFormat:(CLString *) format, ...;
-(id) initWithFormat:(CLString *) format, ...;
-(id) initWithFormat:(CLString *) format arguments:(va_list) argList;
-(CLString *) stringByAppendingFormat:(CLString *) format, ...;
@end

@interface CLString (CLStringMisc)
-(void) getCharacters:(unichar *) buffer;
@end

@interface CLString (CLStringURL)
-(BOOL) isURL;
-(CLString *) urlProtocol;
-(CLString *) urlServer;
-(CLString *) urlHost;
-(CLString *) urlPort;
-(CLString *) urlUser;
-(CLString *) urlPassword;
-(CLString *) urlPath;
-(CLString *) urlBase;
@end

@interface CLString (CLStringLanguage)
-(CLString *) englishMetaphoneString;
@end

#import <ClearLake/CLConstantString.h>

#endif /* _CLSTRING_H */
