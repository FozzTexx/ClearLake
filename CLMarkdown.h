/* Copyright 2016 by
 *   Chris Osborn <fozztexx@fozztexx.com>
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

#ifndef _CLMARKDOWN_H
#define _CLMARKDOWN_H

#import <ClearLake/CLObject.h>

@class CLDictionary;

@interface CLMarkdown:CLObject
{
  CLString *mdstr;
  CLDictionary *linkAttributes;
}

+(id) markdownFromString:(CLString *) aString;
+(id) markdownFromString:(CLString *) aString linkAttributes:(CLDictionary *) laDict;

-(id) init;
-(id) initFromString:(CLString *) aString linkAttributes:(CLDictionary *) laDict;
-(void) dealloc;

-(CLString *) html;
-(CLDictionary *) linkAttributes;

@end

#endif /* _CLMARKDOWN_H */
