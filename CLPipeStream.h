/* Copyright 2015-2016 by
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

#import <ClearLake/CLStream.h>

@class CLString;

@interface CLPipeStream:CLStream <CLStream>
{
  int rfd, wfd;
  int pid;
}

+(CLPipeStream *) streamWithCommand:(CLString *) aCommand mode:(int) aMode;
+(CLPipeStream *) streamWithExecutable:(CLString *) aCommand arguments:(CLArray *) args
				 stdin:(int) sin stdout:(int) sout stderr:(int) serr;

-(id) initWithCommand:(CLString *) aCommand mode:(int) aMode;
-(id) initWithExecutable:(CLString *) aCommand arguments:(CLArray *) args
		   stdin:(int) sin stdout:(int) sout stderr:(int) serr;
-(id) init;
-(void) dealloc;

-(void) closeRead;
-(void) closeWrite;
-(int) closeAndWait;
-(int) pid;

@end
