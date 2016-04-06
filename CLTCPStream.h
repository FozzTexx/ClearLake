/* Copyright 2010-2016 by
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

#ifndef _CLTCPSTREAM_H
#define _CLTCPSTREAM_H

#import <ClearLake/CLStream.h>
#import <ClearLake/CLString.h>

typedef enum {
  CLLineMode = 1,
  CLCharacterMode
} CLStreamMode;

/* FIXME - Convert CLStream to a class cluster and have this inherit from it */

@interface CLTCPStream:CLStream <CLStream>
{
  CLString *host;
  int port;
  int sock;
  id buffer;
  CLStreamMode mode;
  CLStringEncoding enc;
}

+(CLTCPStream *) openConnectionToHost:(CLString *) aHost usingPort:(int) aPort;

-(id) initConnectionToHost:(CLString *) aHost usingPort:(int) aPort;
-(void) dealloc;

-(CLString *) readString;
-(void) writeString:(CLString *) aString;
-(void) close;
-(BOOL) connectToSocket;

@end

#endif /* _CLTCPSTREAM_H */
