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

#ifndef _CLMUTABLESTRING_H
#define _CLMUTABLESTRING_H

#import <ClearLake/CLString.h>

@interface CLMutableString:CLString <CLCopying>
-(void) replaceCharactersInRange:(CLRange) aRange withString:(CLString *) aString;
@end

@interface CLMutableString (CLMutableStringAdditions)
-(void) insertString:(CLString *) aString atIndex:(CLUInteger) anIndex;
-(void) setString:(CLString *) aString;
-(void) setCharacters:(unichar *) aBuffer length:(CLUInteger) length;
-(void) deleteCharactersInRange:(CLRange) aRange;
-(void) appendCharacter:(unichar) aChar;
-(void) appendString:(CLString *) aString;
-(void) appendFormat:(CLString *) format, ...;
-(CLUInteger) replaceOccurrencesOfString:(CLString *) target
			      withString:(CLString *) replacement;
-(CLUInteger) replaceOccurrencesOfString:(CLString *) target
			      withString:(CLString *) replacement
				 options:(CLStringCompareOptions) options
				   range:(CLRange) range;
@end

@interface CLMutableString (CLStringPaths)
-(void) appendPathComponent:(CLString *) aString;
-(void) appendPathExtension:(CLString *) ext;
@end

#endif /* _CLMUTABLESTRING_H */
