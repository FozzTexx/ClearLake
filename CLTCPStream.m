/* Copyright 2010 by Traction Systems, LLC. <http://tractionsys.com/>
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

#import "CLTCPStream.h"
#import "CLStream.h"
#import "CLMutableData.h"

#include <unistd.h>
#include <netdb.h>
#include <ctype.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

@implementation CLTCPStream

+(CLTCPStream *) openConnectionToHost:(CLString *) aHost usingPort:(int) aPort
{
  return [[[self alloc] initConnectionToHost:aHost usingPort:aPort] autorelease];
}

-(id) initConnectionToHost:(CLString *) aHost usingPort:(int) aPort
{
  [super init];
  host = [aHost copy];
  port = aPort;
  sock = -1;
  buffer = nil;
  mode = CLLineMode;
  enc = CLUTF8StringEncoding;

  if (![self connectToSocket]) {
    [self release];
    return nil;
  }
  
  return self;
}

-(void) dealloc
{
  if (sock >= 0)
    [self close];
  [host release];
  [super dealloc];
}

-(CLString *) readString
{
  return CLGetsfd(sock, enc);
}

-(void) writeString:(CLString *) aString
{
  const char *p;
  CLData *aData;

  
  if (enc == CLUTF8StringEncoding) {
    p = [aString UTF8String];
    write(sock, p, strlen(p));
  }
  else {
    aData = [aString dataUsingEncoding:enc];
    write(sock, [aData bytes], [aData length]);
  }

  return;
}

-(void) close
{
  if (sock >= 0)
    close(sock);
  sock = -1;
  return;
}

-(BOOL) connectToSocket
{
  struct sockaddr_in serverAddr;
  int i;
  const char *p, *serverCString;
  struct in_addr hostaddr;
  struct hostent *hp;


  p = serverCString = [host UTF8String];
  for ( ; p && *p && (isdigit(*p) || *p == '.'); p++)
    ;
  if (!*p) {
    hp = [[[[CLMutableData alloc] initWithLength:sizeof(struct hostent)] autorelease]
	   mutableBytes];
    hp->h_length = 4;
    hp->h_addr_list = [[[[CLMutableData alloc] initWithLength:sizeof(int)*2] autorelease]
			mutableBytes];
    hostaddr.s_addr = inet_addr(serverCString);
    if (hostaddr.s_addr) {
      hp->h_addr_list[0] = [[[[CLMutableData alloc] initWithLength:4] autorelease]
			     mutableBytes];
      memcpy(hp->h_addr_list[0], &hostaddr.s_addr, 4);
      hp->h_addr_list[1] = NULL;
    }
    else
      hp = NULL;
  }
  else
    hp = gethostbyname((char *) serverCString);

  if (!hp)
    return NO;

  memset(&serverAddr, 0, sizeof(serverAddr));
  serverAddr.sin_family = AF_INET;
  serverAddr.sin_port = htons(port);

  for (i = 0; hp->h_addr_list[i]; i++) {
    memcpy(&serverAddr.sin_addr, hp->h_addr_list[i], hp->h_length);
    if ((sock = socket(AF_INET, SOCK_STREAM, 0)) < 0)
      return NO;

    if (!connect(sock, (struct sockaddr *) &serverAddr, sizeof(serverAddr)))
      return YES;

    close(sock);
    sock = -1;
  }

  return NO;
}

@end
