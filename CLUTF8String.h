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

/* This is a special class to deal with UTF8 strings. I want to avoid
   converting to unicode and back to UTF8 if all I need is the UTF8
   part. If it needs to do anything more than return the UTF8 encoding
   it will swizzle itself into a CLString. */

#ifndef _CLUTF8STRING_H
#define _CLUTF8STRING_H

#import <ClearLake/CLString.h>

@interface CLUTF8String:CLString
-(id) initWithBytesNoCopy:(const char *) bytes length:(CLUInteger) length
		 encoding:(CLStringEncoding) encoding;
-(void) dealloc;
-(void) swizzle;

/* Methods that require re-encoding as UTF-32 */
-(CLUInteger) length;
-(unichar) characterAtIndex:(CLUInteger) index;
-(void) getCharacters:(unichar *) buffer range:(CLRange) aRange;

/* Things CLUTF8String can do without needing to re-encode */
-(const char *) UTF8String;
@end

#endif /* _CLUTF8STRING_H */
