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

/* This is a special class to be used for swizzling the
   CLConstantString. About all it does is override the dealloc stuff
   and swizzle back into a CLConstantString. Everything else is
   inherited from CLString.

   Not sure if I need to do anything special about retain/release
   stuff. It can't really ever be released although I can swizzle back
   into a CLConstantString and free the unicode buffer. */

#ifndef _CLCONSTANTUNICODESTRING_H
#define _CLCONSTANTUNICODESTRING_H

#import <ClearLake/CLString.h>

@interface CLConstantUnicodeString:CLString
-(void) swizzle;
-(void) dealloc;
#if !DEBUG_RETAIN
-(id) retain;
-(void) release;
-(id) autorelease;
-(CLUInteger) retainCount;
#endif
@end

#endif /* _CLCONSTANTUNICODESTRING_H */
