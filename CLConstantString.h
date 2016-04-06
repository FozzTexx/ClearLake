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

/* This is a special class to deal with gcc and constant strings
   (@"..."). It cannot be freed. If any method besides UTF8String is
   called it will swizzle itself into a CLConstantUnicodeString. */

#ifndef _CLCONSTANTSTRING_H
#define _CLCONSTANTSTRING_H

#import <ClearLake/CLUTF8String.h>

@interface CLConstantString:CLUTF8String
-(void) swizzle;
-(void) dealloc;
#if !DEBUG_RETAIN
-(id) retain;
-(void) release;
-(id) autorelease;
-(CLUInteger) retainCount;
#endif
@end

@interface CLConstantString (LinkerIsBorked)
+(void) linkerIsBorked;
@end

#endif /* _CLCONSTANTSTRING_H */
